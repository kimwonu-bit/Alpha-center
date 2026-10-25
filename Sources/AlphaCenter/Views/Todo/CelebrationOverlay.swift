import SwiftUI

/// 하루 할 일을 모두 끝내면: 사진이 오른쪽 → 왼쪽으로 지나가며 빛줄기·잔상·반짝임을 남기고, 잠시 뒤 모두 사라진다.
struct CelebrationOverlay: View {
    let start: Date

    private struct Burst {
        let x: Double       // 가로 위치 (0...1)
        let y: Double       // 세로 위치 (0...1)
        let colors: [Color]
        let count: Int
        let power: Double
    }

    private let flight = 1.6 / 1.2     // 사진이 가로지르는 시간
    private let fade = 1.0       // 흔적이 사라지는 시간
    private let burstLife = 1.4
    private let bursts: [Burst] = CelebrationOverlay.makeBursts()

    private static func makeBursts() -> [Burst] {
        let palette: [[Color]] = [
            [Color(hex: 0xFFC83D), Color(hex: 0xFF8A1F)],
            [Color(hex: 0x7DB4FF), Color(hex: 0x00B4C5)],
            [Color(hex: 0xFF4A4A), Color(hex: 0xFF2C9E)],
            [Color(hex: 0x20C063), Color(hex: 0xFFE680)],
            [Color(hex: 0xB28CFF), Color(hex: 0xFFFFFF)],
        ]
        let xs: [Double] = [0.88, 0.72, 0.58, 0.46, 0.33, 0.2, 0.1]
        let ys: [Double] = [0.35, 0.62, 0.3, 0.55, 0.38, 0.6, 0.4]
        var list: [Burst] = []
        for i in 0..<xs.count {
            list.append(Burst(x: xs[i], y: ys[i], colors: palette[i % palette.count],
                              count: 34, power: 0.16 + 0.04 * Double(i % 3)))
        }
        return list
    }

    private let photo: NSImage? = Bundle.main.url(forResource: "AlphaMeme", withExtension: "jpg")
        .flatMap { NSImage(contentsOf: $0) }

    /// 사진 중심 x: 화면 오른쪽 밖 → 왼쪽 밖 (진행도 p: 0...1)
    private func xPos(_ p: Double, _ w: CGFloat) -> CGFloat {
        let e = CGFloat(p * p * (3 - 2 * p))
        return w * 1.5 - e * (w * 2)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                scene(t: ctx.date.timeIntervalSince(start), size: geo.size)
            }
        }
        .allowsHitTesting(false)
        .clipped()
    }

    private func scene(t: Double, size: CGSize) -> some View {
        let y = size.height / 2
        let p = min(1, max(0, t / flight))
        let trail = max(0, 1 - max(0, t - flight) / fade)
        return ZStack {
            streak(p: p, trail: trail, size: size, y: y)
            fireworks(t: t, size: size)
            if let photo {
                photoView(photo, size)
                    .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                    .position(x: xPos(p, size.width), y: y)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func photoView(_ photo: NSImage, _ size: CGSize) -> some View {
        Image(nsImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: 0))
    }

    /// 사진이 지나온 길을 따라 남는 빛줄기
    private func streak(p: Double, trail: Double, size: CGSize, y: CGFloat) -> some View {
        let head = xPos(p, size.width)
        let length = max(0, size.width * 1.5 - head)
        let colors: [Color] = [Color(hex: 0xFFD54A).opacity(0), Color(hex: 0xFFB300).opacity(0.55), Color(hex: 0x7DB4FF).opacity(0.6)]
        return Capsule()
            .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .frame(width: length, height: size.height * 0.6)
            .blur(radius: 14)
            .position(x: head + length / 2, y: y)
            .opacity(trail)
    }

    /// 사진이 지나가 드러난 자리마다 폭죽이 터진다
    private func fireworks(t: Double, size: CGSize) -> some View {
        Canvas { gc, sz in
            for b in bursts {
                let t0 = flight * passProgress(atX: b.x * sz.width, width: sz.width)
                let age = t - t0
                guard age > 0, age < burstLife else { continue }
                let k = age / burstLife
                let origin = CGPoint(x: b.x * sz.width, y: b.y * sz.height)
                // 터지는 순간의 섬광
                if k < 0.18 {
                    let r = sz.height * 0.06 * (1 + k * 6)
                    let rect = CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2)
                    gc.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.8 * (1 - k / 0.18))))
                }
                for i in 0..<b.count {
                    let angle = Double(i) / Double(b.count) * 2 * .pi
                    let speed = b.power * sz.height * (0.55 + 0.45 * Double((i * 7) % 10) / 9)
                    let ease = 1 - pow(1 - k, 3)               // 처음엔 빠르게 퍼지고 점점 느려진다
                    let dx = cos(angle) * speed * 5 * ease
                    let dy = sin(angle) * speed * 5 * ease + sz.height * 0.22 * k * k   // 중력
                    let pt = CGPoint(x: origin.x + dx, y: origin.y + dy)
                    let r = CGFloat(3.2 * (1 - k * 0.6))
                    let color = b.colors[i % b.colors.count].opacity(1 - k * k)
                    gc.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(color))
                    // 꼬리
                    let tail = CGPoint(x: pt.x - cos(angle) * 10 * (1 - k), y: pt.y - sin(angle) * 10 * (1 - k))
                    var path = Path()
                    path.move(to: tail)
                    path.addLine(to: pt)
                    gc.stroke(path, with: .color(color.opacity(0.5)), lineWidth: r * 0.8)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    /// 사진 오른쪽 끝이 화면 x에 닿는 진행도 (이동 곡선의 역함수)
    private func passProgress(atX x: Double, width w: Double) -> Double {
        let target = 1 - x / (2 * w)          // 필요한 ease 값
        var lo = 0.0, hi = 1.0
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if mid * mid * (3 - 2 * mid) < target { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }
}
