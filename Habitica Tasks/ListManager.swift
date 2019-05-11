//
//  File.swift
//  Habitica
//
//  Created by Christopher Coffin on 3/12/19.
//  Copyright © 2019 HabitRPG Inc. All rights reserved.
//

import Foundation
import Habitica_API_Client
import Habitica_Database
import ReactiveSwift
import Habitica_Models
import Result


class ListManager: BaseRepository<TaskLocalRepository>, TaskRepositoryProtocol {
    private var savedLists: [String: [String]] = [String: [String]]()
    static let ListsKey = "lists"
    static let GroupId = "group.chabitica.TasksSiri"

    // setting things because I don't know how to get them
    //let userID = "b8e592e4-b686-4582-bd26-5e173ecd9875"
    let userKey = "4688587f-7910-42ae-ac91-94fbf3c95942"

    static let sharedInstance = ListManager()
    let sharedDefaults = UserDefaults(suiteName: ListManager.GroupId)
    
    override init() {
        super.init()
        self.setupNetworkClient()
        print("Auth at start id, ", AuthenticationManager.shared.currentUserId)
        //print("Auth at start key, ", AuthenticationManager.shared.keychain.)
        print("Auth at start key, ", AuthenticationManager.shared.currentUserKey)
        //NetworkAuthenticationManager.shared.currentUserId = self.userID
        NetworkAuthenticationManager.shared.currentUserKey = self.userKey
        // ensure that we have todo, habits, and daily lists
        let listName = "todo"
        if (savedLists[listName] == nil) {
            savedLists[listName] = []
        }
        if let saved = sharedDefaults?.value(forKey: ListManager.ListsKey) {
            savedLists = saved as! [String : [String]]
        }
    }
    
    @objc
    func setupNetworkClient() {
        NetworkAuthenticationManager.shared.currentUserId = AuthenticationManager.shared.currentUserId
        NetworkAuthenticationManager.shared.currentUserKey = AuthenticationManager.shared.currentUserKey
        updateServer()
        //AuthenticatedCall.errorHandler = HabiticaNetworkErrorHandler()
        let configuration = URLSessionConfiguration.default
        //NetworkLogger.enableLogging(for: configuration)
        AuthenticatedCall.defaultConfiguration.urlConfiguration = configuration
    }
    
    func updateServer() {
        if let chosenServer = UserDefaults().string(forKey: "chosenServer") {
            switch chosenServer {
            case "staging":
                AuthenticatedCall.defaultConfiguration = HabiticaServerConfig.staging
            case "beta":
                AuthenticatedCall.defaultConfiguration = HabiticaServerConfig.beta
            case "gamma":
                AuthenticatedCall.defaultConfiguration = HabiticaServerConfig.gamma
            case "delta":
                AuthenticatedCall.defaultConfiguration = HabiticaServerConfig.delta
            default:
                AuthenticatedCall.defaultConfiguration = HabiticaServerConfig.production
            }
        }
    }
    
    func getTasks(predicate: NSPredicate, sortKey: String = "order") -> SignalProducer<ReactiveResults<[TaskProtocol]>, ReactiveSwiftRealmError> {
        /*currentUserIDProducer.skipNil().flatMap(FlattenStrategy.latest, {[weak self] (userID) in
            print ("uuuuuser",  userID)
            return SignalProducer.empty
            })*/
        return currentUserIDProducer.skipNil().flatMap(.latest, {[weak self] (userID) in
            return self?.localRepository.getTasks(userID: userID, predicate: predicate, sortKey: sortKey) ?? SignalProducer.empty
        })
        /*
            return self.localRepository.getTasks(userID: self.userID,
                                             predicate: predicate, sortKey: sortKey)
 */
    }

    /*
    private func fetchTasks() {
        var fetchTasksDisposable: Disposable?
        if let disposable = fetchTasksDisposable, !disposable.isDisposed {
            disposable.dispose()
        }
        fetchTasksDisposable =
            self.getTasks(predicate: NSPredicate(format: "type == 'todo'"), sortKey: "order").on(value: {[weak self] (tasks, changes) in
                print("Ta ta ta ta tasks...", self ?? "no self", tasks, changes ?? "nothing")
            }).start()
    }
     */

    /*
    private func getRemoteTasks() {
        let taskCall = RetrieveTasksCall()
        taskCall.fire()
        /*taskCall.errorSignal.on(event: {(err) in
            print("got error")
        })*/
        print(taskCall.habiticaResponseSignal.on(event: {habiticaResponse in
            print("test")
            print(habiticaResponse)
        }, value: {habiticaResponse in
                print("test")
                print(habiticaResponse ?? "nada")
        }).collect())
        let s = taskCall.arraySignal.on(event: {(event) in
            print("something ", event)
        },
            value: {[weak self] (taskp) in
            print("fffffff tasks...", taskp)
        })
    }*/
    
    func retrieveTasks(dueOnDay: Date? = nil) -> Signal<[TaskProtocol]?, NoError> {
        let call = RetrieveTasksCall(dueOnDay: dueOnDay)
        call.fire()
        return call.arraySignal.on(value: {[weak self] tasks in
            if let tasks = tasks, dueOnDay == nil {
                print("adding new tasks from server")
                self?.localRepository.save(userID: self?.currentUserId, tasks: tasks)
            }
        })
    }
    
    func lists () -> [String : [String]] {
        return savedLists
    }

    /*TaskRepository().login("christopher.coffin@gmail.com", "waterislife")
     let call = RetrieveTasksCall(dueOnDay: nil)
     call.fire()
     var taskList = call.arraySignal.on(value: {[weak self] tasks in
     /*if let tasks = tasks, dueOnDay == nil {
     self?.localRepository.save(userID: self?.currentUserId, tasks: tasks)
     }*/
     })
     */

    
    func tasksForList(withName name: String, oncompletion: @escaping ([String]) -> Void) {
        DispatchQueue.main.sync{
            let signalObserver = Signal<[TaskProtocol]?, NoError>.Observer(
                value: { value in
                    print("Time elapsed = \(value)")
            }, completed: {
                print("DEBUG completed")
            }, interrupted: {
                print("DEBUG interrupted")
            })
            self.retrieveTasks().observe(signalObserver)
            let sp = self.getTasks(predicate: NSPredicate(format: "type == 'todo'"))
            var disposable: Disposable?
            disposable = sp.on(value: {[weak self](tasks, changes) in
                var titles: [String] = []
                tasks.forEach({(task) in
                    if let taskTitle = task.text {
                        titles.append(taskTitle)
                        self?.savedLists[name]?.append(taskTitle)
                    }
                })
                print("DEBUG have titles and changes", titles, changes)
                oncompletion(titles)
                disposable?.dispose()
            }).start()
        }
    }
    
    func add(tasks: [String], toList listName: String, oncompletion: @escaping () -> Void) {
        var list = savedLists[listName] == nil ? [] : savedLists[listName]!
        list.append(contentsOf: tasks)
        updateSavedLists(changedList: list, listName: listName)
        tasks.forEach({(title) in
            createTask(title: title)
        })
        oncompletion()
    }
    
    func createTask(title: String) -> Signal<TaskProtocol?, NoError> {
        var task = localRepository.getNewTask()
        task.text = title
        task.type = "todo"
        localRepository.save(userID: currentUserId, task: task)
        localRepository.setTaskSyncing(userID: currentUserId, task: task, isSyncing: true)
        let call = CreateTaskCall(task: task)
        call.fire()
        return call.objectSignal.on(value: {[weak self]returnedTask in
            if let returnedTask = returnedTask {
                self?.localRepository.save(userID: self?.currentUserId, task: returnedTask)
            }
        })
    }

    
    func finish(task: String) {
        if let listName = self.findTaskInList(withName: task) {
            var list = savedLists[listName]!
            if let index = list.index(of: task) {
                list.remove(at: index)
                updateSavedLists(changedList: list, listName: listName)
            }
        }
    }
    
    private func updateSavedLists(changedList: [String]?, listName: String) {
        savedLists[listName] = changedList
        sharedDefaults?.set(savedLists, forKey: ListManager.ListsKey)
        sharedDefaults?.synchronize()
    }
    
    private func findTaskInList(withName taskName: String) -> String? {
        for (listName, list) in savedLists {
            if list.contains(taskName) {
                return listName
            }
        }
        return nil
    }
}
