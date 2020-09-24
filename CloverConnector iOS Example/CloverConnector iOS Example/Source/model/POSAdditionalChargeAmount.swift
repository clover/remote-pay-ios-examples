//  
//  POSAdditionalChargeAmount.swift
//  CloverConnector iOS Example
//
//  Copyright © 2020 Clover Network. All rights reserved.
//

import Foundation

public class POSAdditionalChargeAmount {
    var id: String?
    var amount: Int?
    var rate: Int64?
    
    init(id: String?, amount: Int?, rate: Int64?) {
        self.id = id
        self.amount = amount
        self.rate = rate
    }
}

