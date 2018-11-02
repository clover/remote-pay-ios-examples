//
//  POSCard.swift
//  ExamplePOS
//
//  
//  Copyright © 2017 Clover Network, Inc. All rights reserved.
//

import Foundation
import CloverConnector

public class POSCard {
    public var name:String?
    public var first6:String
    public var last4:String
    public var month:String
    public var year:String
    public var token:String?
    
    public init(name:String?, first6:String, last4:String, month:String, year:String, token:String?) {
        self.name = name
        self.first6 = first6
        self.last4 = last4
        self.month = month
        self.year = year
        self.token = token
    }
    
    public init?(card:CLVModels.Payments.VaultedCard) {
        guard let first6 = card.first6 else { return nil }
        guard let last4 = card.last4 else { return nil }
        guard let month = (card.expirationDate as NSString?)?.substring(to: 2) else { return nil }
        guard let year = (card.expirationDate as NSString?)?.substring(from: 2) else { return nil }
        self.name = card.cardholderName
        self.first6 = first6
        self.last4 = last4
        self.month = month
        self.year = year
        self.token = card.token
    }

    public var vaultedCard:CLVModels.Payments.VaultedCard {
        let vaultedCard = CLVModels.Payments.VaultedCard()
        vaultedCard.first6 = first6
        vaultedCard.last4 = last4
        vaultedCard.cardholderName = name
        vaultedCard.expirationDate = "\(month)\(year)"
        vaultedCard.token = token
        return vaultedCard
    }
}
