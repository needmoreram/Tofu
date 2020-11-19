import UIKit

class SettingsViewController : UITableViewController {
    @IBAction func didPressDone(_ sender: UIBarButtonItem) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
