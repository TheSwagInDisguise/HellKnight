import UIKit
import SpriteKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = GameViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

final class GameViewController: UIViewController {
    private var presented = false

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        skView.isMultipleTouchEnabled = true
        skView.ignoresSiblingOrder = true
        // 120 Hz on ProMotion displays; game logic is time-based so it runs the same at any rate.
        skView.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        skView.backgroundColor = .black
        Audio.shared.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view as? SKView, !presented, skView.bounds.width > 0 else { return }
        presented = true
        let scene = ShotMode.initialScene(size: skView.bounds.size) ?? TitleScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if let skView = view as? SKView, let scene = skView.scene as? BaseScene {
            scene.relayout()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
}
