import SpriteKit
import UIKit

// MARK: - Grid cells

enum Cell: UInt8 {
    case void, floor, block, pit, lava, spikes
}

struct Pillar {
    let pos: CGPoint
    let r: CGFloat
    var blocksShots: Bool = true
}

/// A placed marker from a template (pillars, props, urns, fountain, altar…).
struct Mark {
    let ch: Character
    let c: Int
    let r: Int
}

// MARK: - Hand-designed layouts
// Legend: ' ' void  '.' floor  '#' stone block  'P' pillar  'O' chasm  '~' burning pool
//         '^' spike trap  'B' brazier  'u' urn  'D' door slot (always in pairs on the top row)
//         'F' fountain  'A' altar  'c' candles  'x' bones
// Top row is the back (door) wall; the player enters at the bottom-centre.

enum Layouts {
    static let combat: [[String]] = [
        [ // Pillared hall with a burning pool
            "..DD....DD....DD..",
            "c................c",
            "..P....~~~~....P..",
            "......~~~~~~......",
            ".......~~~~.......",
            "..P............P..",
            "....u........u....",
            "..................",
            "..P....#..#....P..",
            ".......#..#.......",
            "..................",
            "..P............P..",
            "x................x",
            "..................",
        ],
        [ // Cross
            "    ..DD..DD..    ",
            "    c........c    ",
            "    ..^....^..    ",
            "......#....#......",
            "..u...........u...",
            "..OO..........OO..",
            "..OO....~~....OO..",
            "........~~........",
            "......#....#......",
            "    ..^....^..    ",
            "    ..........    ",
            "    x........x    ",
            "    ..........    ",
        ],
        [ // Chasm bridges
            "..DD....DD....DD..",
            "c................c",
            "..u............u..",
            "OOOOOO..OO..OOOOOO",
            "OOOOOO..OO..OOOOOO",
            "..................",
            "...#....~~....#...",
            "...#....~~....#...",
            "..................",
            "OOOO..OOOOOO..OOOO",
            "OOOO..OOOOOO..OOOO",
            "..................",
            "..^....x..x....^..",
            "..................",
        ],
        [ // L-shaped hall
            "..DD....DD..      ",
            "c...........      ",
            "..P......P..      ",
            "............      ",
            "....~~......      ",
            "....~~...........c",
            "...........#......",
            "..u........#...u..",
            "..................",
            "..P....OOO.....P..",
            ".......OOO........",
            "..................",
            "x....^......^....x",
            "..................",
        ],
        [ // Ring around a central chasm
            "   ..DD....DD..   ",
            "  c............c  ",
            " ................ ",
            "....#........#....",
            "......OOOOOO......",
            "....u.OOOOOO.u....",
            "......OOOOOO......",
            "......OOOOOO......",
            "....#........#....",
            " ...^........^... ",
            " ................ ",
            "  x............x  ",
            "   ............   ",
            "   ............   ",
        ],
        [ // Block maze
            "..DD....DD....DD..",
            "..................",
            ".##...##..##...##.",
            "..................",
            "....~~......~~....",
            ".##....u..u....##.",
            "......#....#......",
            "......#.^^.#......",
            ".##....u..u....##.",
            "....~~......~~....",
            "..................",
            ".##...##..##...##.",
            "c................c",
            "..................",
        ],
        [ // Twin courtyards
            "..DD..........DD..",
            "c.....#....#.....c",
            "......#....#......",
            "..~~..#....#..~~..",
            "..~~..#....#..~~..",
            "......#....#......",
            "......#.uu.#......",
            "..................",
            "..................",
            "...P....^^....P...",
            "..................",
            "..OO..........OO..",
            "x.OO..........OO.x",
            "..................",
        ],
    ]

    static let boss: [[String]] = [
        [
            "      ....DD....      ",
            "    B............B    ",
            "   ................   ",
            "  .....~~....~~.....  ",
            " .....~~......~~..... ",
            "......................",
            "...OO............OO...",
            "...OO............OO...",
            "......................",
            "......................",
            "...OO............OO...",
            "...OO............OO...",
            "......................",
            " .....~~......~~..... ",
            "  .....~~....~~.....  ",
            "   ................   ",
            "    B............B    ",
            "      ..........      ",
        ],
        [
            "     .....DD.....     ",
            "   B..............B   ",
            "  ..................  ",
            " ....^^........^^.... ",
            " .................... ",
            "....OOO........OOO....",
            "....OOO........OOO....",
            "......................",
            "........~~~~~~........",
            "........~~~~~~........",
            "......................",
            "....OOO........OOO....",
            "....OOO........OOO....",
            " .................... ",
            " ....^^........^^.... ",
            "  ..................  ",
            "   B..............B   ",
            "     ............     ",
        ],
    ]

    static let shop: [String] = [
        "  .DD....DD.  ",
        "  c........c  ",
        " ............ ",
        "..............",
        "..............",
        "..............",
        "..............",
        " x..........x ",
        "  ..........  ",
        "  ..........  ",
    ]

    static let rest: [String] = [
        "  .DD....DD.  ",
        "  c........c  ",
        " ............ ",
        "..............",
        "......F.......",
        "..............",
        "..............",
        " x..........x ",
        "  ..........  ",
        "  ..........  ",
    ]

    static let altar: [String] = [
        "  .DD....DD.  ",
        "  c........c  ",
        " ............ ",
        "..B........B..",
        "......A.......",
        "..............",
        "..............",
        " x..........x ",
        "  ..........  ",
        "  ..........  ",
    ]
}

// MARK: - Room

final class Room {
    static let cs: CGFloat = 64

    let bounds: CGRect
    let type: RoomType
    let cols: Int
    let rows: Int
    var cells: [Cell]
    var pillars: [Pillar] = []
    var doorSlots: [Int] = []
    var marks: [Mark] = []
    private var flow: [Int] = []

    init(template: [String], type: RoomType, mirror: Bool) {
        self.type = type
        let lines = template.map { mirror ? String($0.reversed()) : $0 }
        rows = lines.count
        cols = lines.map { $0.count }.max() ?? 1
        let w = CGFloat(cols) * Room.cs
        let h = CGFloat(rows) * Room.cs
        bounds = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        cells = Array(repeating: .void, count: cols * rows)
        for (li, line) in lines.enumerated() {
            let r = rows - 1 - li
            for (c, ch) in line.enumerated() {
                let cell: Cell
                switch ch {
                case " ": cell = .void
                case "#": cell = .block
                case "O": cell = .pit
                case "~": cell = .lava
                case "^": cell = .spikes
                default: cell = .floor
                }
                cells[r * cols + c] = cell
                switch ch {
                case "P", "B", "u", "F", "A", "c", "x":
                    marks.append(Mark(ch: ch, c: c, r: r))
                default:
                    break
                }
            }
        }
        // Door slots: pairs of "DD" on the top row; the slot is the left cell of the pair.
        if let top = lines.first {
            let chars = Array(top)
            var i = 0
            while i < chars.count - 1 {
                if chars[i] == "D" && chars[i + 1] == "D" {
                    doorSlots.append(i)
                    i += 2
                } else {
                    i += 1
                }
            }
        }
    }

    // Geometry helpers

    func cell(_ c: Int, _ r: Int) -> Cell {
        guard c >= 0, r >= 0, c < cols, r < rows else { return .void }
        return cells[r * cols + c]
    }

    func colRow(_ p: CGPoint) -> (Int, Int) {
        (Int(floor((p.x - bounds.minX) / Room.cs)), Int(floor((p.y - bounds.minY) / Room.cs)))
    }

    func center(_ c: Int, _ r: Int) -> CGPoint {
        CGPoint(x: bounds.minX + (CGFloat(c) + 0.5) * Room.cs, y: bounds.minY + (CGFloat(r) + 0.5) * Room.cs)
    }

    func cellRect(_ c: Int, _ r: Int) -> CGRect {
        CGRect(x: bounds.minX + CGFloat(c) * Room.cs, y: bounds.minY + CGFloat(r) * Room.cs, width: Room.cs, height: Room.cs)
    }

    func cellAt(_ p: CGPoint) -> Cell {
        let (c, r) = colRow(p)
        return cell(c, r)
    }

    static func walkable(_ c: Cell) -> Bool { c == .floor || c == .lava || c == .spikes }

    var startPoint: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.minY + 56)
    }

    /// Pushes a circle out of pillars and non-walkable cells.
    func resolve(_ p: CGPoint, _ r: CGFloat) -> CGPoint {
        var q = p
        for pl in pillars {
            let d = q - pl.pos
            let md = pl.r + r
            let l = d.length
            if l < md {
                let n = l > 0.001 ? d * (1 / l) : CGPoint(x: 0, y: 1)
                q = pl.pos + n * md
            }
        }
        for _ in 0..<2 {
            let (c0, r0) = colRow(q)
            for dc in -1...1 {
                for dr in -1...1 {
                    let c = c0 + dc, rr = r0 + dr
                    if Room.walkable(cell(c, rr)) { continue }
                    let rect = cellRect(c, rr)
                    let cx = clamp(q.x, rect.minX, rect.maxX)
                    let cy = clamp(q.y, rect.minY, rect.maxY)
                    let d = CGPoint(x: q.x - cx, y: q.y - cy)
                    let l = d.length
                    if l >= r { continue }
                    if l > 0.001 {
                        q = CGPoint(x: cx, y: cy) + d * (r / l)
                    } else {
                        let left = q.x - rect.minX, right = rect.maxX - q.x
                        let bottom = q.y - rect.minY, top = rect.maxY - q.y
                        let m = min(min(left, right), min(bottom, top))
                        if m == left { q.x = rect.minX - r } else if m == right { q.x = rect.maxX + r }
                        else if m == bottom { q.y = rect.minY - r } else { q.y = rect.maxY + r }
                    }
                }
            }
        }
        q.x = clamp(q.x, bounds.minX + r, bounds.maxX - r)
        q.y = clamp(q.y, bounds.minY + r, bounds.maxY - r)
        return q
    }

    /// True if a walker of radius r can't stand at p.
    func blocked(_ p: CGPoint, _ r: CGFloat) -> Bool {
        if !Room.walkable(cellAt(p)) { return true }
        return resolve(p, r).distance(to: p) > 1
    }

    /// Projectiles fly over chasms and pools but stop at blocks, pillars and the room edge.
    func shotBlocked(_ p: CGPoint) -> Bool {
        let c = cellAt(p)
        if c == .block || c == .void { return true }
        return pillars.contains { $0.blocksShots && $0.pos.distance(to: p) < $0.r }
    }

    func lineOfSight(_ a: CGPoint, _ b: CGPoint) -> Bool {
        let d = b - a
        let n = max(1, Int(d.length / 20))
        for i in 1..<n {
            if shotBlocked(a + d * (CGFloat(i) / CGFloat(n))) { return false }
        }
        return true
    }

    func walkLineClear(_ a: CGPoint, _ b: CGPoint, _ r: CGFloat) -> Bool {
        let d = b - a
        let n = max(1, Int(d.length / 24))
        for i in 1...n {
            let p = a + d * (CGFloat(i) / CGFloat(n))
            let c = cellAt(p)
            if !(c == .floor || c == .spikes) { return false }
            if pillars.contains(where: { $0.pos.distance(to: p) < $0.r + r }) { return false }
        }
        return true
    }

    func randomOpenPoint(margin: CGFloat, avoid: CGPoint, minDist: CGFloat) -> CGPoint {
        var best = startPoint
        var bestD: CGFloat = -1
        for _ in 0..<60 {
            let c = Int.random(in: 0..<cols), r = Int.random(in: 0..<rows)
            guard cell(c, r) == .floor else { continue }
            let p = center(c, r) + CGPoint(x: rnd(-10, 10), y: rnd(-10, 10))
            if blocked(p, margin * 0.6) { continue }
            let d = p.distance(to: avoid)
            if d >= minDist { return p }
            if d > bestD {
                bestD = d
                best = p
            }
        }
        return best
    }

    // MARK: Flow field (enemy pathing)

    func computeFlow(to target: CGPoint) {
        let n = cols * rows
        if flow.count != n { flow = Array(repeating: Int.max, count: n) }
        for i in 0..<n { flow[i] = Int.max }
        let (tc, tr) = colRow(target)
        guard tc >= 0, tr >= 0, tc < cols, tr < rows else { return }
        var queue = [tr * cols + tc]
        flow[tr * cols + tc] = 0
        var head = 0
        let blockedPillar: (Int, Int) -> Bool = { c, r in
            let p = self.center(c, r)
            return self.pillars.contains { $0.pos.distance(to: p) < $0.r + 10 }
        }
        while head < queue.count {
            let cur = queue[head]
            head += 1
            let c = cur % cols, r = cur / cols
            let base = flow[cur]
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)] {
                let nc = c + dc, nr = r + dr
                guard nc >= 0, nr >= 0, nc < cols, nr < rows else { continue }
                let ncell = cell(nc, nr)
                guard ncell == .floor || ncell == .spikes else { continue }
                if dc != 0 && dr != 0 {
                    let a = cell(c + dc, r), b = cell(c, r + dr)
                    if !(a == .floor || a == .spikes) || !(b == .floor || b == .spikes) { continue }
                }
                let ni = nr * cols + nc
                let cost = base + (dc != 0 && dr != 0 ? 14 : 10) + (blockedPillar(nc, nr) ? 30 : 0)
                if cost < flow[ni] {
                    flow[ni] = cost
                    queue.append(ni)
                }
            }
        }
    }

    /// Where a walker at p should head to reach the flow target.
    func steer(from p: CGPoint, to target: CGPoint, radius: CGFloat) -> CGPoint {
        if walkLineClear(p, target, radius * 0.8) { return target }
        let (c, r) = colRow(p)
        var best = target
        var bestV = Int.max
        for dc in -1...1 {
            for dr in -1...1 {
                if dc == 0 && dr == 0 { continue }
                let nc = c + dc, nr = r + dr
                guard nc >= 0, nr >= 0, nc < cols, nr < rows, flow.count == cols * rows else { continue }
                let v = flow[nr * cols + nc]
                if v < bestV {
                    bestV = v
                    best = center(nc, nr)
                }
            }
        }
        return bestV == Int.max ? target : best
    }
}
