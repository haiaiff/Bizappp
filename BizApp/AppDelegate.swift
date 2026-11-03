import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let nav = UINavigationController(rootViewController: WebViewController())
        nav.navigationBar.barTintColor = UIColor(red: 18 / 255, green: 78 / 255, blue: 158 / 255, alpha: 1)
        nav.navigationBar.isTranslucent = false
        nav.navigationBar.barStyle = .black
        nav.navigationBar.tintColor = .white
        nav.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window

        return true
    }
}
