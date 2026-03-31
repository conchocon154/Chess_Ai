import Combine
import SwiftUI
import Foundation

// MARK: - CẤU TRÚC DỮ LIỆU
enum GameMode { case menu, playing }
enum Difficulty { case easy, medium, hard }
enum PieceColor { case white, black }
enum PieceType: Hashable { case pawn, rook, knight, bishop, queen, king }
enum GameState { case playing, checkWhite, checkBlack, checkmateWhiteWins, checkmateBlackWins, stalemate }

struct ChessPiece: Equatable {
    let type: PieceType; let color: PieceColor
    var symbol: String {
        switch (color, type) {
        case (.white, .king): return "♔"; case (.white, .queen): return "♕"
        case (.white, .rook): return "♖"; case (.white, .bishop): return "♗"
        case (.white, .knight): return "♘"; case (.white, .pawn): return "♙"
        case (.black, .king): return "♚"; case (.black, .queen): return "♛"
        case (.black, .rook): return "♜"; case (.black, .bishop): return "♝"
        case (.black, .knight): return "♞"; case (.black, .pawn): return "♟"
        }
    }
}

struct Square: Equatable {
    let row: Int; let column: Int; var piece: ChessPiece?
    var coordinate: String {
        let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
        return "\(letters[column])\(8 - row)"
    }
}

struct MoveHistory {
    let fromRow: Int; let fromCol: Int; let toRow: Int; let toCol: Int
    let movedPiece: ChessPiece; let capturedPiece: ChessPiece?; let notation: String
}

// MARK: - ENGINE
class ChessEngine: ObservableObject {
    @Published var board: [[Square]] = []
    @Published var selectedSquare: Square? = nil
    @Published var isWhiteTurn: Bool = true
    @Published var moveLog: [String] = []
    @Published var history: [MoveHistory] = []
    @Published var gameState: GameState = .playing
    @Published var playAgainstAI: Bool = false
    @Published var isAITurn: Bool = false
    @Published var promotionSquare: Square? = nil

    init() { setupBoard() }

    func setupBoard() {
        var newBoard: [[Square]] = []
        for r in 0..<8 {
            var rowSquares: [Square] = []
            for c in 0..<8 { rowSquares.append(Square(row: r, column: c, piece: nil)) }
            newBoard.append(rowSquares)
        }
        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for c in 0..<8 {
            newBoard[0][c].piece = ChessPiece(type: backRank[c], color: .black)
            newBoard[1][c].piece = ChessPiece(type: .pawn, color: .black)
            newBoard[6][c].piece = ChessPiece(type: .pawn, color: .white)
            newBoard[7][c].piece = ChessPiece(type: backRank[c], color: .white)
        }
        board = newBoard; isWhiteTurn = true; moveLog = []; history = []; gameState = .playing; isAITurn = false
    }

    func isPathClear(from start: Square, to end: Square) -> Bool {
        let rStep = end.row > start.row ? 1 : (end.row < start.row ? -1 : 0)
        let cStep = end.column > start.column ? 1 : (end.column < start.column ? -1 : 0)
        var cr = start.row + rStep; var cc = start.column + cStep
        while cr != end.row || cc != end.column {
            if board[cr][cc].piece != nil { return false }; cr += rStep; cc += cStep
        }
        return true
    }

    // 🌟 SỬA LOGIC DI CHUYỂN TẠI ĐÂY
    func isPseudoLegal(p: ChessPiece, from: Square, to: Square) -> Bool {
        if from.row == to.row && from.column == to.column { return false }
        if let target = to.piece, target.color == p.color { return false }
        let rd = to.row - from.row; let cd = to.column - from.column
        
        switch p.type {
        case .pawn:
            let dir = p.color == .white ? -1 : 1
            let startRow = p.color == .white ? 6 : 1
            if cd == 0 && rd == dir && to.piece == nil { return true }
            if cd == 0 && rd == dir * 2 && from.row == startRow && to.piece == nil {
                return board[from.row + dir][from.column].piece == nil // Kiểm tra vật cản ô giữa
            }
            if abs(cd) == 1 && rd == dir && to.piece != nil { return true }
            return false
        case .knight:
            return (abs(rd) == 2 && abs(cd) == 1) || (abs(rd) == 1 && abs(cd) == 2)
        case .rook:
            return (rd == 0 || cd == 0) && isPathClear(from: from, to: to)
        case .bishop:
            return abs(rd) == abs(cd) && isPathClear(from: from, to: to)
        case .queen:
            return (rd == 0 || cd == 0 || abs(rd) == abs(cd)) && isPathClear(from: from, to: to)
        case .king:
            // Vua chỉ đi 1 ô
            return abs(rd) <= 1 && abs(cd) <= 1
        }
    }

    func handleTap(row: Int, col: Int) {
        if isAITurn || gameState != .playing { return }
        let tapped = board[row][col]
        if let sel = selectedSquare {
            if isPseudoLegal(p: sel.piece!, from: sel, to: tapped) {
                executeMove(from: sel, to: tapped)
            } else {
                selectedSquare = tapped.piece?.color == (isWhiteTurn ? .white : .black) ? tapped : nil
            }
        } else if tapped.piece?.color == (isWhiteTurn ? .white : .black) {
            selectedSquare = tapped
        }
    }

    func executeMove(from: Square, to: Square) {
        let piece = from.piece!
        let note = "\(piece.symbol)\(from.coordinate)→\(to.coordinate)"
        history.append(MoveHistory(fromRow: from.row, fromCol: from.column, toRow: to.row, toCol: to.column, movedPiece: piece, capturedPiece: to.piece, notation: note))
        moveLog.insert(note, at: 0)
        board[to.row][to.column].piece = piece
        board[from.row][from.column].piece = nil
        finalizeTurn()
    }

    func undoMove() {
        guard !history.isEmpty else { return }
        if let last = history.popLast() {
            board[last.fromRow][last.fromCol].piece = last.movedPiece
            board[last.toRow][last.toCol].piece = last.capturedPiece
            if !moveLog.isEmpty { moveLog.removeFirst() }
            isWhiteTurn.toggle()
        }
        isAITurn = false; selectedSquare = nil
    }

    func finalizeTurn() {
        isWhiteTurn.toggle(); selectedSquare = nil
        if playAgainstAI && !isWhiteTurn {
            isAITurn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.makeSimpleAIMove() }
        }
    }

    func makeSimpleAIMove() {
        var moves: [(Square, Square)] = []
        for r in 0..<8 { for c in 0..<8 {
            if let p = board[r][c].piece, p.color == .black {
                for tr in 0..<8 { for tc in 0..<8 {
                    if isPseudoLegal(p: p, from: board[r][c], to: board[tr][tc]) {
                        moves.append((board[r][c], board[tr][tc]))
                    }
                }}
            }
        }}
        if let m = moves.randomElement() { executeMove(from: m.0, to: m.1) }
        isAITurn = false
    }
}

// MARK: - VIEW
struct ContentView: View {
    @StateObject var game = ChessEngine()
    @State private var mode: GameMode = .menu
    let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.12).edgesIgnoringSafeArea(.all)

            if mode == .menu {
                VStack(spacing: 40) {
                    Text("CỜ VUA VUI VẺ").font(.system(size: 60, weight: .black)).foregroundColor(.white)
                    VStack(spacing: 20) {
                        Button("Chơi 2 Người") { game.playAgainstAI = false; game.setupBoard(); mode = .playing }
                            .buttonStyle(MenuBtn(color: .blue))
                        Button("Chơi với Máy") { game.playAgainstAI = true; game.setupBoard(); mode = .playing }
                            .buttonStyle(MenuBtn(color: .orange))
                    }
                }
            } else {
                HStack(spacing: 30) {
                    VStack(spacing: 0) {
                        HStack {
                            Button("⬅ Menu") { mode = .menu }.foregroundColor(.red).padding(.bottom, 10)
                            Spacer()
                            Text(game.isWhiteTurn ? "Lượt Trắng" : "Lượt Đen").foregroundColor(.white).bold()
                        }.frame(width: 430)

                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                ForEach(0..<8) { i in
                                    Text("\(8-i)").frame(width: 30, height: 50).font(.caption).foregroundColor(.gray)
                                }
                            }

                            VStack(spacing: 0) {
                                ForEach(0..<8, id: \.self) { r in
                                    HStack(spacing: 0) {
                                        ForEach(0..<8, id: \.self) { c in
                                            ZStack {
                                                Rectangle()
                                                    .fill((r + c) % 2 == 0 ? Color(red: 0.93, green: 0.93, blue: 0.82) : Color(red: 0.46, green: 0.59, blue: 0.34))
                                                    .frame(width: 50, height: 50)
                                                
                                                if game.selectedSquare?.row == r && game.selectedSquare?.column == c {
                                                    Color.yellow.opacity(0.5).frame(width: 50, height: 50)
                                                }
                                                
                                                if let p = game.board[r][c].piece {
                                                    Text(p.symbol).font(.system(size: 35)).foregroundColor(.black)
                                                }
                                            }
                                            .frame(width: 50, height: 50)
                                            .onTapGesture { game.handleTap(row: r, col: c) }
                                        }
                                    }
                                }
                            }
                            .border(Color.black, width: 2)
                        }

                        HStack(spacing: 0) {
                            Spacer().frame(width: 30)
                            ForEach(letters, id: \.self) { l in
                                Text(l).frame(width: 50).font(.caption).foregroundColor(.gray)
                            }
                        }

                        HStack {
                            Button("↩ Undo") { game.undoMove() }.disabled(game.isAITurn)
                            Spacer()
                            if game.isAITurn { Text("🤖 Đang nghĩ...").foregroundColor(.yellow) }
                            Spacer()
                            Button("🔄 Reset") { game.setupBoard() }.foregroundColor(.red)
                        }.frame(width: 430).padding(.top, 20)
                    }

                    VStack(alignment: .leading) {
                        Text("NHẬT KÝ").font(.headline).foregroundColor(.white)
                        ScrollView {
                            VStack(spacing: 5) {
                                ForEach(game.moveLog, id: \.self) { log in
                                    Text(log).font(.system(.body, design: .monospaced)).padding(6).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.1)).cornerRadius(5).foregroundColor(.white)
                                }
                            }
                        }.frame(width: 150, height: 400)
                    }
                }
            }
        }
    }
}

struct MenuBtn: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 250, height: 60).background(color).foregroundColor(.white).cornerRadius(15).font(.title3.bold())
    }
}
