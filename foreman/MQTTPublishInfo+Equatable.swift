//
//  MQTTPublishInfo+Equatable.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/18.
//

import MQTTNIO

extension MQTTPublishInfo: @retroactive Equatable {
    public static func == (lhs: MQTTPublishInfo, rhs: MQTTPublishInfo) -> Bool {
        lhs.qos == rhs.qos && lhs.retain == rhs.retain && lhs.topicName == rhs.topicName
            && lhs.payload == rhs.payload
    }
}
