#!/usr/bin/env python3
"""
Generateur d'opening book Polyglot pour SixFourChess/SixFour.

Cree un fichier .bin au format Polyglot avec les ouvertures les plus jouees.
Chaque entree : key(8B) + move(2B) + weight(2B) + learn(4B) = 16 bytes, big-endian.
Le fichier DOIT etre trie par key (exigence du format Polyglot).

Usage :
    python3 scripts/generate_opening_book.py

Output :
    SixFourChessApp/SixFourChessApp/Resources/opening_book.bin

Dependance : pip install python-chess
"""

import struct
import chess
import chess.polyglot
from pathlib import Path


# ─── Arbre des ouvertures populaires ───
# Format : {move_uci: (weight, {sous-moves...})}
# Weight plus eleve = plus souvent joue.

OPENING_TREE = {
    # Position initiale
    "e2e4": (100, {
        # 1.e4 e5 (Jeu ouvert)
        "e7e5": (80, {
            "g1f3": (90, {
                "b8c6": (85, {
                    "f1b5": (60, {}),  # Ruy Lopez
                    "f1c4": (40, {}),  # Italienne
                    "d2d4": (30, {}),  # Ecossaise
                }),
                "d7d6": (15, {       # Philidor
                    "d2d4": (80, {}),
                }),
            }),
            "f1c4": (10, {           # Bishop's Opening
                "g8f6": (70, {}),
                "f8c5": (30, {}),
            }),
        }),
        # 1.e4 c5 (Sicilienne)
        "c7c5": (70, {
            "g1f3": (80, {
                "d7d6": (50, {
                    "d2d4": (90, {
                        "c5d4": (85, {
                            "f3d4": (90, {
                                "g8f6": (70, {
                                    "b1c3": (90, {}),  # Najdorf
                                }),
                                "b8c6": (30, {}),      # Classique
                            }),
                        }),
                    }),
                }),
                "b8c6": (30, {
                    "d2d4": (80, {}),
                }),
                "e7e6": (20, {       # Kan/Taimanov
                    "d2d4": (80, {}),
                }),
            }),
            "b1c3": (15, {           # Closed Sicilian
                "b8c6": (50, {}),
                "d7d6": (30, {}),
            }),
            "c2c3": (5, {            # Alapin
                "d7d5": (60, {}),
                "g8f6": (30, {}),
            }),
        }),
        # 1.e4 e6 (Francaise)
        "e7e6": (30, {
            "d2d4": (90, {
                "d7d5": (90, {
                    "b1c3": (40, {
                        "g8f6": (50, {}),
                        "f8b4": (40, {}),  # Winawer
                    }),
                    "b1d2": (30, {        # Tarrasch
                        "g8f6": (60, {}),
                        "c7c5": (30, {}),
                    }),
                    "e4e5": (20, {        # Advance
                        "c7c5": (80, {}),
                    }),
                }),
            }),
        }),
        # 1.e4 c6 (Caro-Kann)
        "c7c6": (25, {
            "d2d4": (80, {
                "d7d5": (90, {
                    "b1c3": (40, {
                        "d5e4": (70, {}),  # Classique
                    }),
                    "e4e5": (30, {        # Advance
                        "c8f5": (70, {}),
                    }),
                    "e4d5": (20, {        # Exchange
                        "c6d5": (90, {}),
                    }),
                }),
            }),
        }),
        # 1.e4 d5 (Scandinave)
        "d7d5": (10, {
            "e4d5": (80, {
                "d8d5": (60, {
                    "b1c3": (90, {}),
                }),
                "g8f6": (30, {}),         # Scandinave moderne
            }),
        }),
        # 1.e4 g6 (Pirc/Modern)
        "g7g6": (5, {
            "d2d4": (80, {
                "f8g7": (90, {
                    "b1c3": (70, {}),
                }),
            }),
        }),
    }),
    # 1.d4
    "d2d4": (90, {
        # 1.d4 d5
        "d7d5": (60, {
            "c2c4": (80, {
                # QGD
                "e7e6": (50, {
                    "b1c3": (60, {
                        "g8f6": (80, {}),
                    }),
                    "g1f3": (30, {
                        "g8f6": (80, {}),
                    }),
                }),
                # QGA
                "d5c4": (25, {
                    "g1f3": (50, {}),
                    "e2e3": (30, {}),
                }),
                # Slav
                "c7c6": (25, {
                    "g1f3": (60, {
                        "g8f6": (80, {}),
                    }),
                    "b1c3": (30, {}),
                }),
            }),
            "g1f3": (15, {
                "g8f6": (80, {}),
                "e7e6": (10, {}),
            }),
        }),
        # 1.d4 Nf6
        "g8f6": (70, {
            "c2c4": (80, {
                # Nimzo/Queen's Indian
                "e7e6": (40, {
                    "b1c3": (50, {
                        "f8b4": (70, {}),  # Nimzo-Indian
                    }),
                    "g1f3": (40, {
                        "b7b6": (60, {}),  # Queen's Indian
                    }),
                }),
                # King's Indian
                "g7g6": (35, {
                    "b1c3": (70, {
                        "f8g7": (90, {
                            "e2e4": (70, {
                                "d7d6": (80, {
                                    "g1f3": (60, {}),
                                    "f1e2": (30, {}),
                                }),
                            }),
                        }),
                    }),
                }),
                # Grunfeld
                "g7g6": (0, {}),  # Already handled above
                "c7c5": (15, {    # Benoni
                    "d4d5": (80, {
                        "e7e6": (50, {}),
                        "b7b5": (20, {}),  # Benko
                    }),
                }),
            }),
            "g1f3": (15, {
                "d7d5": (40, {}),
                "e7e6": (30, {}),
                "g7g6": (20, {}),
            }),
        }),
        # 1.d4 f5 (Dutch)
        "f7f5": (5, {
            "c2c4": (50, {
                "g8f6": (60, {}),
                "e7e6": (30, {}),
            }),
            "g1f3": (30, {
                "g8f6": (70, {}),
            }),
        }),
    }),
    # 1.c4 (English)
    "c2c4": (30, {
        "e7e5": (40, {
            "b1c3": (60, {
                "g8f6": (50, {}),
            }),
            "g1f3": (30, {
                "b8c6": (60, {}),
            }),
        }),
        "g8f6": (30, {
            "b1c3": (50, {}),
            "g1f3": (40, {}),
        }),
        "c7c5": (20, {           # Symetrique
            "g1f3": (60, {}),
            "b1c3": (30, {}),
        }),
    }),
    # 1.Nf3 (Reti)
    "g1f3": (25, {
        "d7d5": (50, {
            "g2g3": (40, {}),
            "c2c4": (40, {}),
        }),
        "g8f6": (30, {
            "g2g3": (40, {}),
            "c2c4": (30, {}),
        }),
        "c7c5": (10, {}),
    }),
    # 1.g3 (King's Fianchetto)
    "g2g3": (5, {
        "d7d5": (50, {}),
        "e7e5": (20, {}),
        "g8f6": (20, {}),
    }),
    # 1.b3 (Larsen)
    "b2b3": (3, {
        "e7e5": (40, {}),
        "d7d5": (30, {}),
    }),
    # 1.f4 (Bird)
    "f2f4": (2, {
        "d7d5": (60, {}),
        "e7e5": (20, {}),  # From's Gambit
    }),
}


def polyglot_move_encode(board: chess.Board, move_uci: str) -> int:
    """
    Encode un coup au format Polyglot 16-bit.

    Format :
      bits 0-2  : to file   (a=0, h=7)
      bits 3-5  : to rank   (1=0, 8=7)
      bits 6-8  : from file
      bits 9-11 : from rank
      bits 12-14: promotion (none=0, knight=1, bishop=2, rook=3, queen=4)

    Cas special : le roque est encode avec la case d'arrivee du ROI
    vers la case de la TOUR (convention Polyglot).
    """
    move = chess.Move.from_uci(move_uci)

    from_file = chess.square_file(move.from_square)
    from_rank = chess.square_rank(move.from_square)
    to_file = chess.square_file(move.to_square)
    to_rank = chess.square_rank(move.to_square)

    # Promotion
    promotion = 0
    if move.promotion:
        promo_map = {
            chess.KNIGHT: 1,
            chess.BISHOP: 2,
            chess.ROOK: 3,
            chess.QUEEN: 4,
        }
        promotion = promo_map.get(move.promotion, 0)

    # Roque : Polyglot encode king → rook square
    if board.is_castling(move):
        if to_file > from_file:  # Petit roque
            to_file = 7  # h-file (tour)
        else:  # Grand roque
            to_file = 0  # a-file (tour)

    encoded = (
        (to_file)
        | (to_rank << 3)
        | (from_file << 6)
        | (from_rank << 9)
        | (promotion << 12)
    )
    return encoded


def build_entries(board: chess.Board, moves_tree: dict, entries: list):
    """
    Parcourt recursivement l'arbre des ouvertures et cree les entrees Polyglot.
    """
    key = chess.polyglot.zobrist_hash(board)

    for move_uci, (weight, sub_tree) in moves_tree.items():
        if weight <= 0:
            continue

        move = chess.Move.from_uci(move_uci)
        if move not in board.legal_moves:
            print(f"  SKIP illegal move: {move_uci} at {board.fen()}")
            continue

        poly_move = polyglot_move_encode(board, move_uci)

        entries.append((key, poly_move, weight, 0))

        if sub_tree:
            board.push(move)
            build_entries(board, sub_tree, entries)
            board.pop()


def write_polyglot_book(entries: list, output_path: Path):
    """
    Ecrit les entrees au format Polyglot binaire.
    Le fichier DOIT etre trie par key (UInt64 big-endian).
    """
    # Trier par key (exigence Polyglot pour recherche binaire)
    entries.sort(key=lambda e: e[0])

    with open(output_path, "wb") as f:
        for key, move, weight, learn in entries:
            # Big-endian : key(8B) + move(2B) + weight(2B) + learn(4B) = 16B
            data = struct.pack(">QHHI", key, move, weight, learn)
            f.write(data)


def main():
    output_path = (
        Path(__file__).parent.parent
        / "SixFourChessApp"
        / "Resources"
        / "opening_book.bin"
    )

    print("Generating Polyglot opening book...")
    print(f"Output: {output_path}")

    board = chess.Board()
    entries = []

    build_entries(board, OPENING_TREE, entries)

    # Deduplicate (same key + move → keep highest weight)
    seen = {}
    for key, move, weight, learn in entries:
        entry_key = (key, move)
        if entry_key not in seen or weight > seen[entry_key][2]:
            seen[entry_key] = (key, move, weight, learn)

    unique_entries = list(seen.values())
    write_polyglot_book(unique_entries, output_path)

    print(f"Done: {len(unique_entries)} entries, {output_path.stat().st_size} bytes")

    # Verification : hash position initiale
    init_hash = chess.polyglot.zobrist_hash(chess.Board())
    print(f"Starting position hash: 0x{init_hash:016X}")
    assert init_hash == 0x463B96181691FC9C, "Hash mismatch!"

    # Compter les coups depuis la position initiale
    init_entries = [e for e in unique_entries if e[0] == init_hash]
    print(f"Moves from starting position: {len(init_entries)}")
    for key, move, weight, _ in sorted(init_entries, key=lambda e: -e[2]):
        print(f"  move=0x{move:04X} weight={weight}")


if __name__ == "__main__":
    main()
