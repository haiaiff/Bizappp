import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 导航栏外观由各页面自行配置（见 WebViewController.setupNavigation）
        let nav = UINavigationController(rootViewController: WebViewController())
        nav.navigationBar.prefersLargeTitles = false
        nav.view.backgroundColor = Theme.paper

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = Theme.paper
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window

        return true
    }
}
