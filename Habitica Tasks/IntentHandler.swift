//
//  IntentHandler.swift
//  Habitica Tasks
//
//  Created by Christopher Coffin on 3/10/19.
//  Copyright © 2019 HabitRPG Inc. All rights reserved.
//
/* Sample intents
 Add the following under Siri intent query:

 Add Task
Add get grocieries to my todo list in Habitica

Show Tasks in a given list
Show my todo list in Habitica
*/

import Intents
import Foundation
import Habitica_Models
import Habitica_Database
import ReactiveSwift
import RealmSwift
import Result


class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling, INAddTasksIntentHandling, INSearchForNotebookItemsIntentHandling, INCreateTaskListIntentHandling, INSetTaskAttributeIntentHandling {

    // TODO remove this since we don't need to create a task list
    func handle(intent: INCreateTaskListIntent, completion: @escaping (INCreateTaskListIntentResponse) -> Void) {
        return
    }

    //Add get groceries to my todo list in Habitica
    func createTasks(fromTitles taskTitles: [String]) -> [INTask] {
        var tasks: [INTask] = []
        tasks = taskTitles.map { taskTitle -> INTask in
            let task = INTask(title: INSpeakableString(spokenPhrase: taskTitle),
                              status: .notCompleted,
                              taskType: .completable,
                              spatialEventTrigger: nil,
                              temporalEventTrigger: nil,
                              createdDateComponents: nil,
                              modifiedDateComponents: nil,
                              identifier: nil)
            return task
        }
        return tasks
    }
    
    // handle for reading the list of task in todo
    func handle(intent: INSearchForNotebookItemsIntent, completion: @escaping (INSearchForNotebookItemsIntentResponse) -> Void) {

        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForNotebookItemsIntent.self))
        //let response = INSearchForNotebookItemsIntentResponse(code: .inProgress, userActivity: userActivity)
        let response = INSearchForNotebookItemsIntentResponse(code: .success, userActivity: userActivity)
        // Initialize with found message's attributes
        /*
         response.tasks = [INTask(
            title: INSpeakableString(spokenPhrase: String("Hardcoded test")),
            status: .notCompleted,
            taskType: .completable,
            spatialEventTrigger: nil,
            temporalEventTrigger: nil,
            createdDateComponents: nil,
            modifiedDateComponents: nil,
            identifier: nil)]
         */
        response.tasks = []
        ListManager.sharedInstance.tasksForList(withName: "todo", oncompletion: {(taskTitles) in
            for taskTitle in taskTitles {
                response.tasks?.append(INTask(
                    title: INSpeakableString(spokenPhrase: taskTitle),
                    status: .notCompleted,
                    taskType: .completable,
                    spatialEventTrigger: nil,
                    temporalEventTrigger: nil,
                    createdDateComponents: nil,
                    modifiedDateComponents: nil,
                    identifier: nil))
            }
            completion(response)
        })
    }
    
    func handle(intent: INSetTaskAttributeIntent, completion: @escaping (INSetTaskAttributeIntentResponse) -> Void) {
        return
    }

    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
    // Implement resolution methods to provide additional information about your intent (optional).
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        if let recipients = intent.recipients {
            
            // If no recipients were provided we'll need to prompt for a value.
            if recipients.count == 0 {
                completion([INSendMessageRecipientResolutionResult.needsValue()])
                return
            }
            
            var resolutionResults = [INSendMessageRecipientResolutionResult]()
            for recipient in recipients {
                let matchingContacts = [recipient] // Implement your contact matching logic here to create an array of matching contacts
                switch matchingContacts.count {
                case 2  ... Int.max:
                    // We need Siri's help to ask user to pick one from the matches.
                    resolutionResults += [INSendMessageRecipientResolutionResult.disambiguation(with: matchingContacts)]
                    
                case 1:
                    // We have exactly one matching contact
                    resolutionResults += [INSendMessageRecipientResolutionResult.success(with: recipient)]
                    
                case 0:
                    // We have no contacts matching the description provided
                    resolutionResults += [INSendMessageRecipientResolutionResult.unsupported()]
                    
                default:
                    break
                    
                }
            }
            completion(resolutionResults)
        }
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty {
            completion(INStringResolutionResult.success(with: text))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    // Once resolution is completed, perform validation on the intent and provide confirmation (optional).
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Verify user is authenticated and your app is ready to send a message.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
        completion(response)
    }
    
    // Handle the completed intent (required).
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Implement your application logic to send a message here.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
        completion(response)
    }
    
    
    func handle(intent: INAddTasksIntent, completion: @escaping (INAddTasksIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INAddTasksIntent.self))
        let taskList = intent.targetTaskList
        // TODO assume todo list if not specified
        
        guard let title = taskList?.title else {
            completion(INAddTasksIntentResponse(code: .failure, userActivity: nil))
            return
        }
        var tasks: [INTask] = []
        if let taskTitles = intent.taskTitles {
            let taskTitlesStrings = taskTitles.map {
                taskTitle -> String in
                return taskTitle.spokenPhrase
            }
            tasks = createTasks(fromTitles: taskTitlesStrings)
            ListManager.sharedInstance.add(tasks: taskTitlesStrings, toList: title.spokenPhrase, oncompletion: {
                // to require app launch
                //let response = INAddTasksIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil)
                let response = INAddTasksIntentResponse(code: .success, userActivity: nil)
                response.modifiedTaskList = intent.targetTaskList
                response.addedTasks = tasks
                completion(response)
            })
        }
    }

    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        // Implement your application logic to find a message that matches the information in the intent.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
        let response = INSearchForMessagesIntentResponse(code: .success, userActivity: userActivity)
        // Initialize with found message's attributes
        response.messages = [INMessage(
            identifier: "identifier",
            content: "I am so excited about SiriKit!",
            dateSent: Date(),
            sender: INPerson(personHandle: INPersonHandle(value: "sarah@example.com", type: .emailAddress), nameComponents: nil, displayName: "Sarah", image: nil,  contactIdentifier: nil, customIdentifier: nil),
            recipients: [INPerson(personHandle: INPersonHandle(value: "+1-415-555-5555", type: .phoneNumber), nameComponents: nil, displayName: "John", image: nil,  contactIdentifier: nil, customIdentifier: nil)]
            )]
        completion(response)
    }
    
    // MARK: - INSetMessageAttributeIntentHandling
    
    func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        // Implement your application logic to set the message attribute here.
        
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))
        let response = INSetMessageAttributeIntentResponse(code: .success, userActivity: userActivity)
        completion(response)
    }
}
