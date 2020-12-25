/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import CoreData

class ViewController: UIViewController {
    // MARK: - Properties
    private let teamCellIdentifier = "teamCellReuseIdentifier"
    lazy var  coreDataStack = CoreDataStack(modelName: "WorldCup")
    lazy var fetchedResultsController: NSFetchedResultsController<Team> = {
        let compareSelector = #selector(NSString.localizedStandardCompare(_:))

        let zoneSort = NSSortDescriptor(
            key: #keyPath(Team.qualifyingZone),
            ascending: true,
            selector: compareSelector
        )

        let scoreSort = NSSortDescriptor(
            key: #keyPath(Team.wins),
            ascending: false
        )

        let nameSort = NSSortDescriptor(
            key: #keyPath(Team.teamName),
            ascending: true,
            selector: compareSelector
        )

        let fetchRequest: NSFetchRequest<Team> = Team.fetchRequest()
        fetchRequest.sortDescriptors = [zoneSort, scoreSort, nameSort]

        let fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: coreDataStack.managedContext,
            sectionNameKeyPath: #keyPath(Team.qualifyingZone),
            cacheName: "WORLD_CUP_FETCH_ALL_TEAM_CACHE"
        )
        fetchedResultsController.delegate = self

        return fetchedResultsController
    }()
    
    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        addButton.isEnabled = true

        importJSONSeedDataIfNeeded()

        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Fetching error: \(error), userInfo: \(error.userInfo)")
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            addButton.isEnabled = true
        }
    }
}

// MARK: - IBActions
extension ViewController {
    @IBAction func addTeam(_ sender: UIButton) {
        let alertController = UIAlertController(
            title: "Secret Team",
            message: "Add a new team",
            preferredStyle: .alert
        )

        alertController.addTextField {
            (textField) in
            textField.placeholder = "Team Name"
        }

        alertController.addTextField {
            (textField) in
            textField.placeholder = "Qualifying Zone"
        }

        let saveAction = UIAlertAction(title: "Save", style: .default, handler: {
            [unowned self] (action) in

            guard let nameTextField = alertController.textFields?.first,
                  let zoneTextField = alertController.textFields?.last
            else {
                return
            }

            let team = Team(context: coreDataStack.managedContext)

            team.teamName = nameTextField.text
            team.qualifyingZone = zoneTextField.text
            team.imageName = "wenderland-flag"

            coreDataStack.saveContext()
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - Internal
extension ViewController {
    func configure(cell: UITableViewCell, for indexPath: IndexPath) {
        guard let cell = cell as? TeamCell
        else {
            return
        }

        let team = fetchedResultsController.object(at: indexPath)
        cell.teamLabel.text = team.teamName
        cell.scoreLabel.text = "Wins: \(team.wins)"

        if let imageName = team.imageName {
            cell.flagImageView.image = UIImage(named: imageName)
        } else {
            cell.flagImageView.image = nil
        }
    }
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionInfo = fetchedResultsController.sections?[section]
        else {
            return 0
        }

        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: teamCellIdentifier, for: indexPath)
        configure(cell: cell, for: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionInfo = fetchedResultsController.sections?[section]
        return sectionInfo?.name
    }
}

// MARK: - UITableViewDelegate
extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let team = fetchedResultsController.object(at: indexPath)
        team.wins += 1
        coreDataStack.saveContext()
    }
}


// MARK: - Helper methods
extension ViewController {
    func importJSONSeedDataIfNeeded() {
        let fetchRequest: NSFetchRequest<Team> = Team.fetchRequest()
        let count = try? coreDataStack.managedContext.count(for: fetchRequest)
        
        guard let teamCount = count,
              teamCount == 0 else {
            return
        }
        
        importJSONSeedData()
    }
    
    // swiftlint:disable force_unwrapping force_cast force_try
    func importJSONSeedData() {
        let jsonURL = Bundle.main.url(forResource: "seed", withExtension: "json")!
        let jsonData = try! Data(contentsOf: jsonURL)
        
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as! [[String: Any]]
            
            for jsonDictionary in jsonArray {
                let teamName = jsonDictionary["teamName"] as! String
                let zone = jsonDictionary["qualifyingZone"] as! String
                let imageName = jsonDictionary["imageName"] as! String
                let wins = jsonDictionary["wins"] as! NSNumber
                
                let team = Team(context: coreDataStack.managedContext)
                team.teamName = teamName
                team.imageName = imageName
                team.qualifyingZone = zone
                team.wins = wins.int32Value
            }
            
            coreDataStack.saveContext()
            print("Imported \(jsonArray.count) teams")
        } catch let error as NSError {
            print("Error importing teams: \(error)")
        }
    }
    // swiftlint:enable force_unwrapping force_cast force_try
}

// MARK: - NSFetchedResultsControllerDelegate
extension ViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        case .move:
            if let indexPath = indexPath,
               let newIndexPath = newIndexPath {
                // there is bug in this delegate which calls move instead of update
                // when there is a single row in a section
                if indexPath == newIndexPath {
                    self.controller(controller, didChange: anObject, at: indexPath, for: .update, newIndexPath: newIndexPath)
                } else {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    tableView.insertRows(at: [newIndexPath], with: .automatic)
                }
            }
        case .update:
            if  let indexPath = indexPath,
                let cell = tableView.cellForRow(at: indexPath) as? TeamCell {
                configure(cell: cell, for: indexPath)
            }
        @unknown default:
            break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange sectionInfo: NSFetchedResultsSectionInfo,
                    atSectionIndex sectionIndex: Int,
                    for type: NSFetchedResultsChangeType) {

        let indexSet = IndexSet(integer: sectionIndex)
        switch type {
        case .insert:
            tableView.insertSections(indexSet, with: .automatic)
        case .delete:
            tableView.deleteSections(indexSet, with: .automatic)
        default:
            break
        }
    }
}
