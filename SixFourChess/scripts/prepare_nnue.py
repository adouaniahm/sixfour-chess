#!/usr/bin/env python3
"""
Pipeline NNUE pour SixFourChess/SixFour.

Genere des positions d'echecs evaluees, entraine un reseau NNUE,
et exporte le modele au format CoreML (.mlmodelc) pret pour iOS.

Architecture NNUE :
    768 (12 planes x 64 cases) -> 256 -> 32 -> 32 -> 1
    Activation : Clipped ReLU (clamp 0..1)
    Output : score en pawns (positif = avantage blanc)

Etapes :
    1. Generer ~100k positions avec evaluations (materiel + positionnel)
    2. Entrainer le modele PyTorch (~30 epochs)
    3. Exporter en CoreML FLOAT16
    4. Compiler en .mlmodelc via xcrun
    5. Copier le modèle compilé dans les ressources de l'application

Usage :
    python3 scripts/prepare_nnue.py

Output :
    scripts/output/nnue.mlmodelc/       (modele compile)
    SixFourChess/Resources/nnue.mlmodelc/ (modèle embarqué par l'app)

Dependances : pip install torch coremltools python-chess numpy
"""

import os
import sys
import random
import struct
import shutil
import subprocess
from pathlib import Path

import chess
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import coremltools as ct


# ─── Configuration ───

OUTPUT_DIR = Path(__file__).parent / "output"
NUM_POSITIONS = 100_000        # Positions d'entrainement
BATCH_SIZE = 512
EPOCHS = 30
LEARNING_RATE = 1e-3
DEVICE = "cpu"                  # MPS dispo sur Mac mais CPU suffit pour 100k


# ─── Modele NNUE ───

class ClippedReLU(nn.Module):
    """ReLU clippe a [0, 1] — activation standard NNUE."""
    def forward(self, x):
        return torch.clamp(x, 0.0, 1.0)


class NNUEModel(nn.Module):
    """
    Reseau NNUE : 768 -> 256 -> 32 -> 32 -> 1

    Input : 768 features binaires (12 planes x 64 cases)
    Output : score en pawns (float, positif = avantage blanc)

    L'architecture est volontairement simple pour tourner vite
    sur le Neural Engine iOS (< 1ms par inference).
    """

    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(768, 256),
            ClippedReLU(),
            nn.Linear(256, 32),
            ClippedReLU(),
            nn.Linear(32, 32),
            ClippedReLU(),
            nn.Linear(32, 1),
        )

    def forward(self, x):
        return self.net(x)


# ─── Encodage des positions ───

def board_to_features(board: chess.Board) -> np.ndarray:
    """
    Encode un echiquier en feature vector 768-dim.

    Meme format que BoardEncoder.swift :
    - Planes 0-5  : pieces blanches (pion, cavalier, fou, tour, dame, roi)
    - Planes 6-11 : pieces noires
    - Dans chaque plane : row-major, row 0 = rang 8 (convention app)
    """
    features = np.zeros(768, dtype=np.float32)

    piece_to_channel = {
        (chess.PAWN, chess.WHITE): 0,
        (chess.KNIGHT, chess.WHITE): 1,
        (chess.BISHOP, chess.WHITE): 2,
        (chess.ROOK, chess.WHITE): 3,
        (chess.QUEEN, chess.WHITE): 4,
        (chess.KING, chess.WHITE): 5,
        (chess.PAWN, chess.BLACK): 6,
        (chess.KNIGHT, chess.BLACK): 7,
        (chess.BISHOP, chess.BLACK): 8,
        (chess.ROOK, chess.BLACK): 9,
        (chess.QUEEN, chess.BLACK): 10,
        (chess.KING, chess.BLACK): 11,
    }

    for square in chess.SQUARES:
        piece = board.piece_at(square)
        if piece:
            channel = piece_to_channel[(piece.piece_type, piece.color)]
            # python-chess: square 0 = a1, rank 0 = rang 1
            # App: row 0 = rang 8
            rank = chess.square_rank(square)  # 0-7 (0=rang1)
            file = chess.square_file(square)  # 0-7 (0=a)
            app_row = 7 - rank
            app_col = file
            square_index = app_row * 8 + app_col
            features[channel * 64 + square_index] = 1.0

    return features


# ─── Evaluation heuristique (pour generer les labels) ───

PIECE_VALUES = {
    chess.PAWN: 100,
    chess.KNIGHT: 320,
    chess.BISHOP: 330,
    chess.ROOK: 500,
    chess.QUEEN: 900,
    chess.KING: 0,
}

# Tables de position (perspective blanche, rang 8 en haut = index 0)
PAWN_TABLE = [
     0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
     5,  5, 10, 25, 25, 10,  5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5, -5,-10,  0,  0,-10, -5,  5,
     5, 10, 10,-20,-20, 10, 10,  5,
     0,  0,  0,  0,  0,  0,  0,  0,
]

KNIGHT_TABLE = [
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
]

BISHOP_TABLE = [
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
]

ROOK_TABLE = [
     0,  0,  0,  0,  0,  0,  0,  0,
     5, 10, 10, 10, 10, 10, 10,  5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
     0,  0,  0,  5,  5,  0,  0,  0,
]

KING_MG_TABLE = [
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -10,-20,-20,-20,-20,-20,-20,-10,
     20, 20,  0,  0,  0,  0, 20, 20,
     20, 30, 10,  0,  0, 10, 30, 20,
]

PST = {
    chess.PAWN: PAWN_TABLE,
    chess.KNIGHT: KNIGHT_TABLE,
    chess.BISHOP: BISHOP_TABLE,
    chess.ROOK: ROOK_TABLE,
    chess.KING: KING_MG_TABLE,
}


def evaluate_position(board: chess.Board) -> float:
    """
    Evaluation heuristique en centipawns (positif = avantage blanc).

    Combine materiel + tables de position + mobilite + securite du roi.
    Plus sophistiquee que le simple comptage de materiel pour generer
    des labels d'entrainement de meilleure qualite.
    """
    if board.is_checkmate():
        return -10000.0 if board.turn == chess.WHITE else 10000.0
    if board.is_stalemate() or board.is_insufficient_material():
        return 0.0

    score = 0.0

    for square in chess.SQUARES:
        piece = board.piece_at(square)
        if not piece:
            continue

        # Materiel
        value = PIECE_VALUES.get(piece.piece_type, 0)

        # Position (table)
        rank = chess.square_rank(square)
        file = chess.square_file(square)

        if piece.piece_type in PST:
            if piece.color == chess.WHITE:
                table_index = (7 - rank) * 8 + file
            else:
                table_index = rank * 8 + file
            value += PST[piece.piece_type][table_index]

        if piece.color == chess.WHITE:
            score += value
        else:
            score -= value

    # Bonus mobilite (nombre de coups legaux)
    mobility = board.legal_moves.count()
    score += (mobility - 20) * 2 if board.turn == chess.WHITE else -(mobility - 20) * 2

    # Bonus paire de fous
    white_bishops = len(board.pieces(chess.BISHOP, chess.WHITE))
    black_bishops = len(board.pieces(chess.BISHOP, chess.BLACK))
    if white_bishops >= 2:
        score += 30
    if black_bishops >= 2:
        score -= 30

    return score


# ─── Generation de positions ───

def generate_positions(n: int) -> list[tuple[np.ndarray, float]]:
    """
    Genere n positions d'echecs avec leur evaluation.

    Methode : jouer des parties aleatoires avec des coups semi-intelligents,
    et evaluer chaque position rencontree.
    """
    positions = []
    games_needed = n // 40 + 1  # ~40 positions par partie

    print(f"Generating {n} positions from ~{games_needed} games...")

    for game_idx in range(games_needed):
        if game_idx % 500 == 0:
            print(f"  Game {game_idx}/{games_needed} ({len(positions)}/{n} positions)")

        board = chess.Board()
        moves_played = 0

        while not board.is_game_over() and moves_played < 80:
            legal = list(board.legal_moves)
            if not legal:
                break

            # Semi-random : 70% meilleur coup (capture/check), 30% aleatoire
            if random.random() < 0.3:
                move = random.choice(legal)
            else:
                # Preferer captures et echecs
                scored = []
                for m in legal:
                    s = 0
                    if board.is_capture(m):
                        s += 100
                    if board.gives_check(m):
                        s += 50
                    # Petit bruit pour variete
                    s += random.randint(0, 30)
                    scored.append((s, m))
                scored.sort(key=lambda x: -x[0])
                move = scored[0][1]

            board.push(move)
            moves_played += 1

            # Enregistrer la position (skip les 4 premiers coups)
            if moves_played >= 4 and len(positions) < n:
                features = board_to_features(board)
                score = evaluate_position(board) / 100.0  # En pawns
                # Clipper le score a [-15, 15] pour eviter les outliers
                score = max(-15.0, min(15.0, score))
                positions.append((features, score))

        if len(positions) >= n:
            break

    print(f"Generated {len(positions)} positions")
    return positions[:n]


# ─── Dataset PyTorch ───

class ChessDataset(Dataset):
    def __init__(self, positions):
        self.features = torch.stack([torch.from_numpy(f) for f, _ in positions])
        self.scores = torch.tensor([s for _, s in positions], dtype=torch.float32).unsqueeze(1)

    def __len__(self):
        return len(self.scores)

    def __getitem__(self, idx):
        return self.features[idx], self.scores[idx]


# ─── Entrainement ───

def train_model(positions):
    """Entraine le modele NNUE sur les positions generees."""
    print(f"\nTraining NNUE model ({len(positions)} positions, {EPOCHS} epochs)...")

    # Split train/val 90/10
    random.shuffle(positions)
    split = int(0.9 * len(positions))
    train_data = ChessDataset(positions[:split])
    val_data = ChessDataset(positions[split:])

    train_loader = DataLoader(train_data, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = DataLoader(val_data, batch_size=BATCH_SIZE)

    model = NNUEModel().to(DEVICE)
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=EPOCHS)
    criterion = nn.MSELoss()

    best_val_loss = float("inf")
    best_state = None

    for epoch in range(EPOCHS):
        # Train
        model.train()
        train_loss = 0.0
        for features, scores in train_loader:
            features, scores = features.to(DEVICE), scores.to(DEVICE)
            optimizer.zero_grad()
            pred = model(features)
            loss = criterion(pred, scores)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * features.size(0)

        train_loss /= len(train_data)

        # Validation
        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for features, scores in val_loader:
                features, scores = features.to(DEVICE), scores.to(DEVICE)
                pred = model(features)
                loss = criterion(pred, scores)
                val_loss += loss.item() * features.size(0)

        val_loss /= len(val_data)
        scheduler.step()

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_state = model.state_dict().copy()

        if (epoch + 1) % 5 == 0 or epoch == 0:
            print(f"  Epoch {epoch+1:3d}/{EPOCHS}  train_loss={train_loss:.4f}  val_loss={val_loss:.4f}  lr={scheduler.get_last_lr()[0]:.6f}")

    # Restaurer le meilleur modele
    model.load_state_dict(best_state)
    print(f"  Best val_loss: {best_val_loss:.4f}")

    return model


# ─── Export CoreML ───

def export_coreml(model: NNUEModel, output_dir: Path):
    """
    Exporte le modele PyTorch en CoreML (.mlmodel puis .mlmodelc).

    Le modele est quantise en FLOAT16 pour reduire la taille (~50%)
    tout en gardant une precision suffisante pour l'evaluation d'echecs.
    """
    print("\nExporting to CoreML...")

    model.eval()

    # Tracer le modele avec un input exemple
    example_input = torch.randn(1, 768)
    traced = torch.jit.trace(model, example_input)

    # Conversion CoreML
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="features", shape=(1, 768))],
        outputs=[ct.TensorType(name="evaluation")],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS17,
    )

    # Metadata
    mlmodel.author = "SixFourChess AI Pipeline"
    mlmodel.short_description = "NNUE chess position evaluator (768->256->32->32->1)"
    mlmodel.version = "1.0.0"

    # Sauvegarder le .mlpackage (format requis pour mlprogram / iOS17+)
    mlpackage_path = output_dir / "nnue.mlpackage"
    if mlpackage_path.exists():
        shutil.rmtree(mlpackage_path)
    mlmodel.save(str(mlpackage_path))
    pkg_size = sum(f.stat().st_size for f in mlpackage_path.rglob("*") if f.is_file())
    print(f"  Saved: {mlpackage_path} ({pkg_size / 1024:.0f} KB)")

    # Compiler en .mlmodelc via xcrun
    mlmodelc_path = output_dir / "nnue.mlmodelc"
    if mlmodelc_path.exists():
        shutil.rmtree(mlmodelc_path)

    print("  Compiling with xcrun coremlcompiler...")
    result = subprocess.run(
        ["xcrun", "coremlcompiler", "compile", str(mlpackage_path), str(output_dir)],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"  ERROR: {result.stderr}")
        sys.exit(1)

    if mlmodelc_path.exists():
        # Calculer la taille du dossier .mlmodelc
        total_size = sum(f.stat().st_size for f in mlmodelc_path.rglob("*") if f.is_file())
        print(f"  Compiled: {mlmodelc_path} ({total_size / 1024:.0f} KB)")
    else:
        print("  WARNING: .mlmodelc not found after compilation")

    return mlmodelc_path


def copy_to_app_resources(mlmodelc_path: Path):
    """
    Copie le .mlmodelc dans les ressources versionnées de l'application.
    """
    app_resources = Path(__file__).parent.parent / "SixFourChess" / "Resources"
    app_resources.mkdir(parents=True, exist_ok=True)

    dest = app_resources / "nnue.mlmodelc"
    if dest.exists():
        shutil.rmtree(dest)

    shutil.copytree(mlmodelc_path, dest)
    print(f"\n  Copied to: {dest}")
    print("  The app will load the bundled model at its next launch.")


def verify_model(model: NNUEModel):
    """Verifie que le modele produit des evaluations sensees."""
    print("\nVerification...")
    model.eval()

    test_positions = [
        ("Position initiale", chess.Board()),
        ("Apres 1.e4", chess.Board("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1")),
        ("Blanc +1 cavalier", chess.Board("rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 0 1")),
        ("Noir +1 dame", chess.Board("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR w KQkq - 0 1")),
        ("Roi blanc seul", chess.Board("rnbqkbnr/pppppppp/8/8/8/8/8/4K3 w kq - 0 1")),
    ]

    for name, board in test_positions:
        features = torch.from_numpy(board_to_features(board)).unsqueeze(0)
        with torch.no_grad():
            score = model(features).item()
        print(f"  {name:30s} -> {score:+.2f} pawns ({score * 100:+.0f} cp)")


# ─── Main ───

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Generer les positions
    positions = generate_positions(NUM_POSITIONS)

    # 2. Entrainer
    model = train_model(positions)

    # 3. Verifier
    verify_model(model)

    # 4. Exporter CoreML
    mlmodelc_path = export_coreml(model, OUTPUT_DIR)

    # 5. Copier dans Application Support (pour test local)
    if mlmodelc_path.exists():
        copy_to_app_resources(mlmodelc_path)

    print("\n" + "=" * 60)
    print("DONE!")
    print(f"  Package: {OUTPUT_DIR / 'nnue.mlpackage'}")
    print(f"  Model:   {OUTPUT_DIR / 'nnue.mlmodelc'}")
    print(f"  ZIP:     {OUTPUT_DIR / 'nnue.mlmodelc.zip'}")
    print("=" * 60)


if __name__ == "__main__":
    main()
