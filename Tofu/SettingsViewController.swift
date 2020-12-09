import UIKit

class SettingsViewController : UITableViewController {
    @IBAction func didToggleBioAuth(_ sender: UISwitch) {
        
    }

    @IBAction func didPressDone(_ sender: UIBarButtonItem) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
