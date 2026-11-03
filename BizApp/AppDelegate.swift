import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        Theme.apply(to: window)
        window.rootViewController = makeRoot()
        window.makeKeyAndVisible()

        // 切换深/浅时重建根控制器：动态色与图层描边（CGColor）一并刷新
        Theme.onChange = { [weak self] in
            guard let self = self, let window = self.window else { return }
            Theme.apply(to: window)
            window.rootViewController = self.makeRoot()
        }

        return true
    }

    /// 导航栏外观由各页面自行配置（见 WebViewController.setupNavigation）
    private func makeRoot() -> UIViewController {
        let nav = UINavigationController(rootViewController: WebViewController())
        nav.navigationBar.prefersLargeTitles = false
        nav.view.backgroundColor = Theme.paper
        return nav
    }
}
