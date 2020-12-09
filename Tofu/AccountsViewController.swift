import UIKit

private let accountOrderKey = "persistentRefs"

class AccountsViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var emptyView: UIView!

    private let keychain = Keychain()
    private var accounts = [Account]()
    private let settings = Settings()
    private let qrImporter = UIImagePickerController()

    private lazy var searchController = makeSearchController()
    private lazy var addAccountAlertController = makeAddAccountAlertController()

    override func viewDidLoad() {
        super.viewDidLoad()

        accounts = keychain.accounts
        let sortedPersistentRefs = UserDefaults.standard.array(forKey: accountOrderKey) as? [Data] ?? []
        accounts.sort { a, b in
            let aIndex = sortedPersistentRefs.firstIndex(of: a.persistentRef! as Data) ?? 0
            let bIndex = sortedPersistentRefs.firstIndex(of: b.persistentRef! as Data) ?? 0
            return aIndex < bIndex
        }
        persistAccountOrder()

        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        }

        let updater = AccountsTableViewUpdater(tableView: tableView)
        updater.startUpdating()

        updateEditing()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deselectSelectedTableViewRow),
            name: UIMenuController.willHideMenuNotification,
            object: nil)
        
        qrImporter.delegate = self
    }

    @objc func deselectSelectedTableViewRow() {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    @IBAction func addAccount(_ sender: Any) {
        present(addAccountAlertController, animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let navigationController = segue.destination as? UINavigationController {
            if let settingsViewController = navigationController.topViewController
                as? SettingsViewController {
                // settingsViewController.delegate = self
            } else if let accountCreationViewController = navigationController.topViewController
                as? AccountCreationViewController {
                accountCreationViewController.delegate = self
            } else {
                let scanningViewController = navigationController.topViewController
                    as! ScanningViewController
                scanningViewController.delegate = self
            }
        } else {
            let accountUpdateViewController = segue.destination
                as! AccountUpdateViewController
            let cell = sender as! AccountCell
            accountUpdateViewController.delegate = self
            accountUpdateViewController.account = cell.account
        }
    }

    private func makeSearchController() -> UISearchController {
        let searchResultsController = storyboard!.instantiateViewController(withIdentifier: "AccountSearchResultsViewController") as! AccountSearchResultsViewController
        let searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchResultsUpdater = self
        return searchController
    }

    private func makeAddAccountAlertController() -> UIAlertController {
        let title = "Add Account"
        let message = "Add an account by scanning a QR code, importing a QR image, or entering a secret manually."
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

        let scanQRCode = UIAlertAction(title: "Scan QR Code", style: .default) { [unowned self] _ in
            self.performSegue(withIdentifier: "ScanSegue", sender: self)
        }
        
        let importQRCode = UIAlertAction(title: "Import QR Image", style: .default) { [unowned self] _ in
            self.qrImporter.allowsEditing = false
            self.qrImporter.sourceType = .photoLibrary
            
            if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary) {
                self.present(self.qrImporter, animated: true, completion: nil)
            } else {
                let importAlert = UIAlertController(title: "Error",
                                                    message: "Unable to access photo library.",
                                                    preferredStyle: .alert)
                importAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(importAlert, animated: true, completion: nil)
            }
        }

        let enterManually = UIAlertAction(title: "Enter Manually", style: .default) { [unowned self] _ in
            self.performSegue(withIdentifier: "EnterManuallySegue", sender: self)
        }

        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(scanQRCode)
        alertController.addAction(importQRCode)
        alertController.addAction(enterManually)
        alertController.addAction(cancel)

        return alertController
    }
    
    private func persistAccountOrder() {
        let sortedPersistentRefs = accounts.map { $0.persistentRef! }
        UserDefaults.standard.set(sortedPersistentRefs, forKey: accountOrderKey)
    }

    private func updateEditing() {
        if accounts.count == 0 {
            if #available(iOS 11.0, *) {
                // In this case the search bar is rendered in the navigation bar and there's no need to hide it when there are no accounts.
            } else {
                tableView.tableHeaderView = nil
            }
            tableView.backgroundView = emptyView
            tableView.separatorStyle = .none
            navigationItem.leftBarButtonItem = nil
            setEditing(false, animated: true)
        } else {
            if #available(iOS 11.0, *) {
                // Since the search bar is already rendered in the navigation bar we don't need to render it in the table header view.
            } else {
                tableView.tableHeaderView = searchController.searchBar
            }
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
            navigationItem.leftBarButtonItem = editButtonItem
        }
    }
    
    // MARK: UIImagePickerControlDelegate
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)
        
        guard let selectedQRCode = info[UIImagePickerController.InfoKey.originalImage] as? UIImage,
            let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                      context: nil,
                                      options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
            let ciImage = CIImage(image: selectedQRCode),
            let features = detector.features(in: ciImage) as? [CIQRCodeFeature],
            let messageString = features.first?.messageString,
            let qrCodeURL = URL(string: messageString),
            let account = Account(url: qrCodeURL) else {
                let noQRAlert = UIAlertController(title: "Error",
                                                  message: "Failed to detect QR code in the provided image.",
                                                  preferredStyle: .alert)
                noQRAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(noQRAlert, animated: true, completion: nil)
                return
        }

        self.createAccount(account)
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) ->
        Bool {
            return true
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath,
                            to destinationIndexPath: IndexPath) {
        accounts.insert(accounts.remove(at: sourceIndexPath.row),
                        at: destinationIndexPath.row)
        persistAccountOrder()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell",
                                                 for: indexPath) as! AccountCell
        cell.account = accounts[indexPath.row]
        cell.delegate = self
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let alertController = UIAlertController(
                title: "Deleting This Account Will Not Turn Off Two-Factor Authentication",
                message: "Please make sure two-factor authentication is turned off in the issuer's sett" +
                "ings before deleting this account to prevent being locked out.",
                preferredStyle: .actionSheet)

            let deleteAccountAction = UIAlertAction(title: "Delete Account", style: .destructive) { _ in
                self.deleteAccountForRowAtIndexPath(indexPath)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            alertController.addAction(deleteAccountAction)
            alertController.addAction(cancelAction)

            present(alertController, animated: true, completion: nil)
        }
    }

    private func deleteAccountForRowAtIndexPath(_ indexPath: IndexPath) {
        let account = self.accounts[indexPath.row]
        guard self.keychain.deleteAccount(account) else {
            presentTryAgainAlertWithTitle(
                "Could Not Delete Account",
                message: "An error occurred when deleting the account from the keychain.") {
                    self.deleteAccountForRowAtIndexPath(indexPath)
            }
            return
        }
        accounts.remove(at: indexPath.row)
        persistAccountOrder()
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateEditing()
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            tableView.deselectRow(at: indexPath, animated: true)

            if let cell = tableView.cellForRow(at: indexPath) as? AccountCell {
                performSegue(withIdentifier: "EditAccountSegue", sender: cell)
            }
        } else { // Not editing
            if let cell = tableView.cellForRow(at: indexPath) {
                guard let cellSuperview = cell.superview else {
                    assertionFailure("The cell does not seem to be in the view hierarchy. How is that even possible!?")
                    return
                }

                let menuController = UIMenuController.shared

                // If you tap the same cell twice, this condition prevents the menu from being
                // hidden and then instantly shown again causing an unpleasant flash.
                //
                // Since the cell could already be the first responder (from previously showing
                // its menu and then scrolling the table view) and the menu could already be
                // visible for another cell, we make sure to check both values.
                if !(cell.isFirstResponder && menuController.isMenuVisible) {
                    cell.becomeFirstResponder()

                    menuController.setTargetRect(cell.frame, in: cellSuperview)
                    menuController.setMenuVisible(true, animated: true)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView,
                            shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, canPerformAction action: Selector,
                            forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }

    override func tableView(_ tableView: UITableView, performAction action: Selector,
                            forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            let cell = tableView.cellForRow(at: indexPath) as! AccountCell
            cell.copy(self)
        }
    }
}

extension AccountsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let accountSearchResultsViewController = searchController.searchResultsController
            as! AccountSearchResultsViewController
        accountSearchResultsViewController.accounts = accounts.filter {
            guard let string = searchController.searchBar.text else { return false }
            return $0.description.range(of: string, options: .caseInsensitive, range: nil,
                                        locale: nil) != nil
        }
    }
}

extension AccountsViewController: AccountCreationDelegate {
    func createAccount(_ account: Account) {
        guard keychain.insertAccount(account) else {
            presentTryAgainAlertWithTitle(
                "Could Not Create Account",
                message: "An error occurred when inserting the account into the keychain.") {
                    self.createAccount(account)
            }
            return
        }
        accounts.append(account)
        persistAccountOrder()
        let lastRow = accounts.count - 1
        let indexPaths = [IndexPath(row: lastRow, section: 0)]
        tableView.insertRows(at: indexPaths, with: .automatic)
        updateEditing()
    }
}

extension AccountsViewController: AccountUpdateDelegate {
    func updateAccount(_ account: Account) {
        guard keychain.updateAccount(account) else {
            presentTryAgainAlertWithTitle(
                "Could Not Update Account",
                message: "An error occurred when persisting the account updates to the keychain.") {
                    self.updateAccount(account)
            }
            return
        }
        let row = accounts.firstIndex { $0 === account }!
        let indexPath = IndexPath(row: row, section: 0)
        guard let cell = tableView.cellForRow(at: indexPath) as? AccountCell else { return }
        cell.updateWithDate(Date())
    }

    private func presentTryAgainAlertWithTitle(_ title: String, message: String, handler: @escaping () -> Void) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let tryAgainAccountAction = UIAlertAction(title: "Try again", style: .default) { _ in
            handler()
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(tryAgainAccountAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}

extension AccountsViewController: SettingsUpdateDelegate {
    func updateSettings(_ changes: ListOfSettings) {
        guard settings.updateSettings(changes) else {
            presentTryAgainAlertWithTitle(
                "Could Not Update Settings",
                message: "An error occurred when trying to save settings.") {
                self.updateSettings(changes)
            }
            return
        }
    }
}
