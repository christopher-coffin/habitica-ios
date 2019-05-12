//
//  RejectQuestInvitationCall.swift
//  Habitica API Client
//
//  Created by Phillip Thelen on 03.05.18.
//  Copyright © 2018 HabitRPG Inc. All rights reserved.
//

import Foundation
import Habitica_Models
import ReactiveSwift

public class RejectQuestInvitationCall: ResponseObjectCall<QuestStateProtocol, APIQuestState> {
    public init(groupID: String, stubHolder: StubHolderProtocol? = StubHolder(responseCode: 200, stubFileName: "group.json")) {
        super.init(httpMethod: .POST, endpoint: "groups/\(groupID)/quests/reject", postData: nil, stubHolder: stubHolder)
    }
}
