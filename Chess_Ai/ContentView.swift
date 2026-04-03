import Combine
import Foundation
import SwiftUI

// MARK: - ENUMS & MODELS
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
    var value: Int {
        switch type {
        case .pawn: return 10; case .knight: return 30; case .bishop: return 30
        case .rook: return 50; case .queen: return 90; case .king: return 9000
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

struct MoveHistory: Identifiable {
    let id = UUID() // 🌟 Thêm ID duy nhất cho SwiftUI
    let fromRow: Int; let fromCol: Int; let toRow: Int; let toCol: Int
    let movedPiece: ChessPiece; let capturedPiece: ChessPiece?; let notation: String
}

// MARK: - CHESS ENGINE
class ChessEngine: ObservableObject {
    @Published var board: [[Square]] = []
    @Published var selectedSquare: Square? = nil
    @Published var isWhiteTurn: Bool = true
    @Published var moveLog: [String] = []
    @Published var history: [MoveHistory] = []
    @Published var gameState: GameState = .playing
    @Published var playAgainstAI: Bool = false
    @Published var aiDifficulty: Difficulty = .medium
    @Published var isAITurn: Bool = false
    @Published var promotionSquare: Square? = nil
    @Published var validDestinations: [(Int, Int)] = [] // 🌟 THÊM DÒNG NÀY
    
    // MARK: - AI HEURISTICS (BẢNG ĐIỂM VỊ TRÍ)
        let pawnTable = [
            [ 0,  0,  0,  0,  0,  0,  0,  0],
            [ 5, 10, 10,-20,-20, 10, 10,  5],
            [ 5, -5,-10,  0,  0,-10, -5,  5],
            [ 0,  0,  0, 20, 20,  0,  0,  0],
            [ 5,  5, 10, 25, 25, 10,  5,  5],
            [10, 10, 20, 30, 30, 20, 10, 10],
            [50, 50, 50, 50, 50, 50, 50, 50],
            [ 0,  0,  0,  0,  0,  0,  0,  0]
        ]
        let knightTable = [
            [-50, -40, -30, -30, -30, -30, -40, -50],
            [-40, -20,   0,   5,   5,   0, -20, -40],
            [-30,   5,  10,  15,  15,  10,   5, -30],
            [-30,   0,  15,  20,  20,  15,   0, -30],
            [-30,   5,  15,  20,  20,  15,   0, -30],
            [-30,   0,  10,  15,  15,  10,   0, -30],
            [-40, -20,   0,   0,   0,   0, -20, -40],
            [-50, -40, -30, -30, -30, -30, -40, -50]
        ]
        let bishopTable = [
            [-20, -10, -10, -10, -10, -10, -10, -20],
            [-10,   5,   0,   0,   0,   0,   5, -10],
            [-10,  10,  10,  10,  10,  10,  10, -10],
            [-10,   0,  10,  10,  10,  10,   0, -10],
            [-10,   5,   5,  10,  10,   5,   5, -10],
            [-10,   0,   5,  10,  10,   5,   0, -10],
            [-10,   0,   0,   0,   0,   0,   0, -10],
            [-20, -10, -10, -10, -10, -10, -10, -20]
        ]
        let rookTable = [
            [ 0,  0,  0,  5,  5,  0,  0,  0],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [ 5, 10, 10, 10, 10, 10, 10,  5],
            [ 0,  0,  0,  0,  0,  0,  0,  0]
        ]
        let queenTable = [
            [-20, -10, -10, -5, -5, -10, -10, -20],
            [-10,   0,   5,  0,  0,   0,   0, -10],
            [-10,   5,   5,  5,  5,   5,   0, -10],
            [  0,   0,   5,  5,  5,   5,   0,  -5],
            [ -5,   0,   5,  5,  5,   5,   0,  -5],
            [-10,   0,   5,  5,  5,   5,   0, -10],
            [-10,   0,   0,  0,  0,   0,   0, -10],
            [-20, -10, -10, -5, -5, -10, -10, -20]
        ]

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
        self.board = newBoard; isWhiteTurn = true; moveLog = []; history = []; gameState = .playing; isAITurn = false; selectedSquare = nil
    }

    // --- HÀM KIỂM TRA CHIẾU TƯỚNG (GIẢI QUYẾT LỖI SCOPE) ---
    func isKingInCheck(color: PieceColor, on b: [[Square]]) -> Bool {
        var kPos: (Int, Int)?
        for r in 0..<8 { for c in 0..<8 {
            if let p = b[r][c].piece, p.type == .king, p.color == color { kPos = (r,c) }
        }}
        guard let kp = kPos else { return false }
        let enemy: PieceColor = color == .white ? .black : .white
        for r in 0..<8 { for c in 0..<8 {
            if let p = b[r][c].piece, p.color == enemy, isPseudoLegal(p: p, from: b[r][c], to: b[kp.0][kp.1], on: b) { return true }
        }}
        return false
    }

    func isPseudoLegal(p: ChessPiece, from: Square, to: Square, on b: [[Square]]) -> Bool {
        if from.row == to.row && from.column == to.column { return false }
        if let target = to.piece, target.color == p.color { return false }
        let rd = to.row - from.row; let cd = to.column - from.column
        
        switch p.type {
        case .pawn:
            let dir = p.color == .white ? -1 : 1
            if cd == 0 && rd == dir && to.piece == nil { return true }
            if cd == 0 && rd == dir*2 && from.row == (p.color == .white ? 6 : 1) && to.piece == nil {
                return b[from.row + dir][from.column].piece == nil
            }
            if abs(cd) == 1 && rd == dir && to.piece != nil { return true }
            return false
        case .knight: return (abs(rd) == 2 && abs(cd) == 1) || (abs(rd) == 1 && abs(cd) == 2)
        case .king: return abs(rd) <= 1 && abs(cd) <= 1
        case .rook: return (rd == 0 || cd == 0) && isPathClear(from: from, to: to, on: b)
        case .bishop: return abs(rd) == abs(cd) && isPathClear(from: from, to: to, on: b)
        case .queen: return (rd == 0 || cd == 0 || abs(rd) == abs(cd)) && isPathClear(from: from, to: to, on: b)
        }
    }

    func isPathClear(from start: Square, to end: Square, on b: [[Square]]) -> Bool {
        let rStep = end.row > start.row ? 1 : (end.row < start.row ? -1 : 0)
        let cStep = end.column > start.column ? 1 : (end.column < start.column ? -1 : 0)
        var cr = start.row + rStep; var cc = start.column + cStep
        while cr != end.row || cc != end.column {
            if b[cr][cc].piece != nil { return false }; cr += rStep; cc += cStep
        }
        return true
    }

    func handleTap(row: Int, col: Int) {
            if isAITurn || promotionSquare != nil || gameState.isGameOver { return }
            let tapped = board[row][col]
            
            if let sel = selectedSquare {
                // Đang có quân được chọn, thử đi đến ô tapped
                if isPseudoLegal(p: sel.piece!, from: sel, to: tapped, on: board) {
                    var sim = board
                    sim[row][col].piece = sel.piece; sim[sel.row][sel.column].piece = nil
                    if !isKingInCheck(color: sel.piece!.color, on: sim) {
                        executeMove(from: sel, to: tapped)
                        return
                    }
                }
                // Đổi sang chọn quân khác của phe mình
                if tapped.piece?.color == (isWhiteTurn ? .white : .black) {
                    selectedSquare = tapped
                    updateValidDestinations(for: tapped) // 🌟 TÍNH TOÁN ĐƯỜNG ĐI
                } else {
                    // Bấm ra ngoài hoặc bấm quân địch không hợp lệ -> Hủy chọn
                    selectedSquare = nil
                    validDestinations = [] // 🌟 XÓA ĐƯỜNG ĐI
                }
            } else if tapped.piece?.color == (isWhiteTurn ? .white : .black) {
                // Bấm chọn quân cờ lần đầu
                selectedSquare = tapped
                updateValidDestinations(for: tapped) // 🌟 TÍNH TOÁN ĐƯỜNG ĐI
            }
        }
    
    // Tính toán và lưu lại các ô mà quân cờ đang chọn có thể đi tới
        func updateValidDestinations(for sq: Square) {
            validDestinations = []
            guard let p = sq.piece else { return }
            
            for tr in 0..<8 {
                for tc in 0..<8 {
                    let toSq = board[tr][tc]
                    // 1. Kiểm tra luật di chuyển cơ bản
                    if isPseudoLegal(p: p, from: sq, to: toSq, on: board) {
                        // 2. Kiểm tra xem đi xong Vua có bị chiếu không
                        var sim = board
                        sim[tr][tc].piece = p
                        sim[sq.row][sq.column].piece = nil
                        if !isKingInCheck(color: p.color, on: sim) {
                            validDestinations.append((tr, tc))
                        }
                    }
                }
            }
        }

    func executeMove(from: Square, to: Square) {
        let piece = from.piece!
        let note = "\(piece.symbol)\(from.coordinate)→\(to.coordinate)"
        history.append(MoveHistory(fromRow: from.row, fromCol: from.column, toRow: to.row, toCol: to.column, movedPiece: piece, capturedPiece: to.piece, notation: note))
        moveLog.insert(note, at: 0)
        board[to.row][to.column].piece = piece
        board[from.row][from.column].piece = nil
        if piece.type == .pawn && (to.row == 0 || to.row == 7) {
            promotionSquare = board[to.row][to.column]; return
        }
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
        gameState = .playing; isAITurn = false; selectedSquare = nil
        validDestinations = [] // Xóa các dấu chấm gợi ý sau khi đi xong hoặc lùi bước
    }
    
    // HÀM XỬ LÝ KHI NGƯỜI CHƠI CHỌN QUÂN PHONG CẤP
        func promotePawn(to pieceType: PieceType) {
            if let promo = promotionSquare {
                // Thay Tốt bằng quân cờ mới chọn (giữ nguyên màu)
                board[promo.row][promo.column].piece = ChessPiece(type: pieceType, color: promo.piece!.color)
                
                // Xóa trạng thái chờ phong cấp và tiếp tục ván đấu
                promotionSquare = nil
                finalizeTurn()
            }
        }

    func finalizeTurn() {
        isWhiteTurn.toggle(); selectedSquare = nil
        validDestinations = [] // Xóa các dấu chấm gợi ý sau khi đi xong hoặc lùi bước
        let current = isWhiteTurn ? PieceColor.white : .black
        let inCheck = isKingInCheck(color: current, on: board)
        
        // KIỂM TRA CHIẾU BÍ
        let legalMoves = getAllLegalMoves(for: current)
        if legalMoves.isEmpty {
            gameState = inCheck ? (isWhiteTurn ? .checkmateBlackWins : .checkmateWhiteWins) : .stalemate
        } else {
            gameState = inCheck ? (isWhiteTurn ? .checkWhite : .checkBlack) : .playing
        }
        
        if !gameState.isGameOver && playAgainstAI && !isWhiteTurn {
            isAITurn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.makeAIMove() }
        }
    }

    // MARK: - HỆ THỐNG TRÍ TUỆ NHÂN TẠO (AI CORE)
        
        // 1. Đánh giá thế cờ (Tính điểm)
        func evaluateBoard(on b: [[Square]]) -> Int {
            var score = 0
            for r in 0..<8 {
                for c in 0..<8 {
                    if let p = b[r][c].piece {
                        var posScore = 0
                        // Lật ngược bảng điểm cho quân Đen
                        let tableRow = (p.color == .white) ? r : (7 - r)
                        
                        switch p.type {
                        case .pawn: posScore = pawnTable[tableRow][c]
                        case .knight: posScore = knightTable[tableRow][c]
                        case .bishop: posScore = bishopTable[tableRow][c]
                        case .rook: posScore = rookTable[tableRow][c]
                        case .queen: posScore = queenTable[tableRow][c]
                        case .king: posScore = 0 // Vua có thể thêm bảng an toàn sau
                        }
                        
                        // Điểm = Giá trị quân + Vị trí đứng
                        let pieceValue = p.value + posScore
                        // AI cầm quân Đen -> Muốn điểm Đen là số Dương
                        score += (p.color == .black) ? pieceValue : -pieceValue
                    }
                }
            }
            return score
        }

        // 2. Thuật toán Minimax + Alpha-Beta Pruning
        func alphaBeta(depth: Int, alpha: Int, beta: Int, isMaximizing: Bool, tempBoard: [[Square]]) -> Int {
            if depth == 0 {
                return evaluateBoard(on: tempBoard)
            }
            
            var currAlpha = alpha
            var currBeta = beta
            let color: PieceColor = isMaximizing ? .black : .white
            let moves = getAllLegalMoves(for: color, on: tempBoard)
            
            // Kiểm tra chiếu bí
            if moves.isEmpty {
                if isKingInCheck(color: color, on: tempBoard) {
                    return isMaximizing ? -999999 : 999999 // Thua
                }
                return 0 // Hòa
            }
            
            if isMaximizing {
                var maxEval = -1000000
                for move in moves {
                    var simBoard = tempBoard
                    simBoard[move.1.row][move.1.column].piece = simBoard[move.0.row][move.0.column].piece
                    simBoard[move.0.row][move.0.column].piece = nil // Giả lập đi cờ
                    
                    let eval = alphaBeta(depth: depth - 1, alpha: currAlpha, beta: currBeta, isMaximizing: false, tempBoard: simBoard)
                    maxEval = max(maxEval, eval)
                    currAlpha = max(currAlpha, eval)
                    if currBeta <= currAlpha { break } // Cắt nhánh vô ích
                }
                return maxEval
            } else {
                var minEval = 1000000
                for move in moves {
                    var simBoard = tempBoard
                    simBoard[move.1.row][move.1.column].piece = simBoard[move.0.row][move.0.column].piece
                    simBoard[move.0.row][move.0.column].piece = nil // Giả lập đi cờ
                    
                    let eval = alphaBeta(depth: depth - 1, alpha: currAlpha, beta: currBeta, isMaximizing: true, tempBoard: simBoard)
                    minEval = min(minEval, eval)
                    currBeta = min(currBeta, eval)
                    if currBeta <= currAlpha { break } // Cắt nhánh vô ích
                }
                return minEval
            }
        }

        // 3. Hàm lấy nước đi hợp lệ trên MỘT BÀN CỜ BẤT KỲ
        func getAllLegalMoves(for color: PieceColor, on b: [[Square]]? = nil) -> [(Square, Square)] {
            let targetBoard = b ?? self.board // Dùng bàn cờ ảo hoặc bàn cờ thật
            var moves: [(Square, Square)] = []
            
            for r in 0..<8 {
                for c in 0..<8 {
                    if let p = targetBoard[r][c].piece, p.color == color {
                        let fromSq = targetBoard[r][c]
                        for tr in 0..<8 {
                            for tc in 0..<8 {
                                let toSq = targetBoard[tr][tc]
                                if isPseudoLegal(p: p, from: fromSq, to: toSq, on: targetBoard) {
                                    var sim = targetBoard
                                    sim[tr][tc].piece = p
                                    sim[r][c].piece = nil
                                    if !isKingInCheck(color: color, on: sim) {
                                        moves.append((fromSq, toSq))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return moves
        }

        // 4. Ra lệnh cho máy đi
        func makeAIMove() {
            // 1. Chụp lại bàn cờ hiện tại
            let currentBoard = self.board
            
            // 2. Thực hiện so sánh ĐỘ KHÓ ngay trên luồng chính và lưu thành biến Bool an toàn
            let isEasyMode = (self.aiDifficulty == .easy)
            let isHardMode = (self.aiDifficulty == .hard)
            
            // 3. Chạy tính toán nặng trên luồng nền
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                let moves = self.getAllLegalMoves(for: .black, on: currentBoard)
                if moves.isEmpty { return }
                
                var bestMove = moves[0]
                
                // 4. Sử dụng trực tiếp biến Bool thay vì so sánh enum ở đây
                if isEasyMode {
                    // Dễ: Đi ngẫu nhiên nhưng ưu tiên ăn quân
                    let captures = moves.filter { currentBoard[$0.1.row][$0.1.column].piece != nil }
                    bestMove = captures.randomElement() ?? moves.randomElement()!
                } else {
                    // Trung Bình (Độ sâu 2) - Khó (Độ sâu 3)
                    let searchDepth = isHardMode ? 3 : 2
                    var bestValue = -1000000
                    
                    for move in moves {
                        var simBoard = currentBoard
                        simBoard[move.1.row][move.1.column].piece = simBoard[move.0.row][move.0.column].piece
                        simBoard[move.0.row][move.0.column].piece = nil
                        
                        // Quét Alpha Beta
                        let boardValue = self.alphaBeta(depth: searchDepth - 1, alpha: -1000000, beta: 1000000, isMaximizing: false, tempBoard: simBoard)
                        
                        if boardValue > bestValue {
                            bestValue = boardValue
                            bestMove = move
                        }
                    }
                }
                
                // 5. Trở về luồng chính cập nhật giao diện
                DispatchQueue.main.async {
                    self.executeMove(from: bestMove.0, to: bestMove.1)
                    self.isAITurn = false
                }
            }
        }
}

// MARK: - EXTENSIONS
extension GameState {
    var isGameOver: Bool {
        return self == .checkmateWhiteWins || self == .checkmateBlackWins || self == .stalemate
    }
}

// MARK: - VIEW (GIAO DIỆN)
struct ContentView: View {
    @StateObject var game = ChessEngine()
    @State private var mode: GameMode = .menu
    @State private var showAIDiff: Bool = false
    
    let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]
    
    var body: some View {
        ZStack {
            
            
            
            Color(red: 0.1, green: 0.1, blue: 0.12).edgesIgnoringSafeArea(.all)
            
            if mode == .menu {
                VStack(spacing: 30) {
                    Text("CỜ VUA SWIFT").font(.system(size: 60, weight: .black)).foregroundColor(.white)
                    if !showAIDiff {
                        Button("🤝 Chơi 2 Người") { game.playAgainstAI = false; game.setupBoard(); mode = .playing }
                            .buttonStyle(MenuBtnStyle(color: .blue))
                        Button("🤖 Chơi với Máy") { withAnimation { showAIDiff = true } }
                            .buttonStyle(MenuBtnStyle(color: .orange))
                    } else {
                        VStack(spacing: 15) {
                            Button("Dễ") { startAI(.easy) }.buttonStyle(MenuBtnStyle(color: .green))
                            Button("Trung Bình") { startAI(.medium) }.buttonStyle(MenuBtnStyle(color: .orange))
                            Button("Khó") { startAI(.hard) }.buttonStyle(MenuBtnStyle(color: .red))
                            Button("Quay lại") { withAnimation { showAIDiff = false } }.foregroundColor(.gray)
                        }
                    }
                }
            } else {
                GeometryReader { geo in
                    let boardSize = min(geo.size.width * 0.7, geo.size.height * 0.8)
                    let cellSize = boardSize / 8
                    
                    HStack(spacing: 20) {
                        Spacer()
                        VStack(spacing: 0) {
                            HStack {
                                Button("⬅ Menu") { mode = .menu; showAIDiff = false }.foregroundColor(.red).bold()
                                Spacer()
                                if game.gameState == .checkWhite || game.gameState == .checkBlack {
                                    Text("⚠️ CHIẾU TƯỚNG!").foregroundColor(.red).bold()
                                }
                                Text(game.isWhiteTurn ? "Lượt Trắng" : "Lượt Đen").foregroundColor(.white).bold()
                            }.frame(width: boardSize + 30).padding(.bottom, 10)
                            
                            HStack(spacing: 0) {
                                VStack(spacing: 0) { ForEach(0..<8) { i in Text("\(8-i)").frame(width: 25, height: cellSize).font(.caption).foregroundColor(.gray) } }
                                VStack(spacing: 0) {
                                    ForEach(0..<8, id: \.self) { r in
                                        HStack(spacing: 0) {
                                            ForEach(0..<8, id: \.self) { c in
                                                ZStack {
                                                    Rectangle().fill((r+c)%2==0 ? Color(red: 0.93, green: 0.93, blue: 0.82) : Color(red: 0.46, green: 0.59, blue: 0.34)).frame(width: cellSize, height: cellSize)
                                                    if game.selectedSquare?.row == r && game.selectedSquare?.column == c { Color.yellow.opacity(0.4).frame(width: cellSize, height: cellSize) }
                                                    // --- BẮT ĐẦU ĐOẠN THÊM MỚI ---
                                                    if game.validDestinations.contains(where: { $0.0 == r && $0.1 == c }) {
                                                        if game.board[r][c].piece != nil {
                                                            // Ô có quân địch -> Vẽ vòng khuyên bao quanh
                                                            Circle()
                                                                .strokeBorder(Color.black.opacity(0.3), lineWidth: cellSize * 0.08)
                                                                .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                                                        } else {
                                                            // Ô trống -> Vẽ dấu chấm mờ ở giữa
                                                            Circle()
                                                                .fill(Color.black.opacity(0.25))
                                                                .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                                                        }
                                                    }
                                                    // --- KẾT THÚC ĐOẠN THÊM MỚI ---
                                                    if let p = game.board[r][c].piece { Text(p.symbol).font(.system(size: cellSize * 0.7)).foregroundColor(.black) }
                                                }.onTapGesture { game.handleTap(row: r, col: c) }
                                            }
                                        }
                                    }
                                }.border(Color.black, width: 2)
                            }
                            HStack(spacing: 0) {
                                Spacer().frame(width: 25)
                                ForEach(letters, id: \.self) { l in Text(l).frame(width: cellSize).font(.caption).foregroundColor(.gray) }
                            }
                            HStack {
                                Button("↩ Undo") { game.undoMove() }.disabled(game.isAITurn)
                                Spacer()
                                if game.isAITurn { Text("🤖 Máy đang nghĩ...").foregroundColor(.yellow) }
                                Spacer()
                                Button("🔄 Reset") { game.setupBoard() }.foregroundColor(.red)
                            }.frame(width: boardSize + 30).padding(.top, 20)
                        }
                        
                        // NHẬT KÝ BÊN PHẢI (Ẩn nếu màn hình quá hẹp)
                        if geo.size.width > 800 {
                            VStack(alignment: .leading) {
                                Text("NHẬT KÝ")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ScrollView {
                                    VStack(spacing: 5) {
                                        // 🌟 Duyệt ngược mảng history và dùng id của nó
                                        ForEach(game.history.reversed()) { move in
                                            Text(move.notation)
                                                .font(.system(.body, design: .monospaced))
                                                .padding(6)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(5)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .frame(width: 150, height: boardSize)
                            }
                        }
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // ... (Đoạn POPUP KẾT THÚC CŨ) ...
                        if game.gameState.isGameOver {
                            Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)
                            VStack(spacing: 20) {
                                Text(game.gameState == .stalemate ? "HÒA CỜ!" : "CHIẾU BÍ!").font(.system(size: 40, weight: .black)).foregroundColor(.white)
                                Text(game.gameState == .checkmateWhiteWins ? "TRẮNG THẮNG" : (game.gameState == .checkmateBlackWins ? "ĐEN THẮNG" : "Không bên nào thắng")).foregroundColor(.gray)
                                Button("Chơi ván mới") { game.setupBoard() }.buttonStyle(.borderedProminent)
                                Button("Quay lại Menu") { mode = .menu; game.setupBoard() }.foregroundColor(.blue)
                            }.padding(40).background(Color.white).cornerRadius(20)
                        }
                        
                        // 🌟 THÊM MỚI: POPUP PHONG CẤP TỐT 🌟
                        if let promoSquare = game.promotionSquare {
                            Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)
                            VStack(spacing: 20) {
                                Text("PHONG CẤP TỐT!").font(.largeTitle).bold().foregroundColor(.white)
                                
                                HStack(spacing: 20) {
                                    // Lặp qua 4 lựa chọn để tạo nút bấm
                                    ForEach([PieceType.queen, .rook, .bishop, .knight], id: \.self) { type in
                                        Button(action: {
                                            game.promotePawn(to: type)
                                        }) {
                                            Text(ChessPiece(type: type, color: promoSquare.piece!.color).symbol)
                                                .font(.system(size: 60))
                                                .foregroundColor(.black)
                                                .frame(width: 90, height: 90)
                                                .background(Color.white)
                                                .cornerRadius(15)
                                                .shadow(radius: 5)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(40)
                            .background(Color.gray)
                            .cornerRadius(25)
                            .shadow(radius: 20)
                        }        }
    }
    
    func startAI(_ d: Difficulty) {
        game.playAgainstAI = true; game.aiDifficulty = d; game.setupBoard(); withAnimation { mode = .playing }
    }
}

struct MenuBtnStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 280, height: 55).background(color).foregroundColor(.white).cornerRadius(12).font(.title3.bold())
    }
}
