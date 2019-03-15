//
//  File.swift
//  Habitica
//
//  Created by Christopher Coffin on 3/12/19.
//  Copyright © 2019 HabitRPG Inc. All rights reserved.
//

import Foundation
import Habitica_API_Client

class ListManager {
    private var savedLists: [String: [String]] = [String: [String]]()
    static let ListsKey = "lists"
    static let GroupId = "group.chabitica.TasksSiri"
    static let sharedInstance = ListManager()
    let sharedDefaults = UserDefaults(suiteName: ListManager.GroupId)

    init() {
        if let saved = sharedDefaults?.value(forKey: ListManager.ListsKey) {
            savedLists = saved as! [String : [String]]
        }
    }
    
    func lists () -> [String : [String]] {
        return savedLists
    }
    
    func tasksForList(withName name: String) -> [String] {
        let call = RetrieveTasksCall(dueOnDay: nil)
        call.fire()
        var taskList = call.arraySignal.on(value: {[weak self] tasks in
            /*if let tasks = tasks, dueOnDay == nil {
                self?.localRepository.save(userID: self?.currentUserId, tasks: tasks)
            }*/
        })
        //HabiticaAppDelegate
        if let tasks = savedLists[name] {
            return tasks
        }
        return []
    }
    
    func add(tasks: [String], toList listName: String) {
        var list = savedLists[listName] == nil ? [] : savedLists[listName]!
        list.append(contentsOf: tasks)
        updateSavedLists(changedList: list, listName: listName)
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
