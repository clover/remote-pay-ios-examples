//
//  POSStore.swift
//  ExamplePOS
//
//  
//  Copyright © 2017 Clover Network, Inc. All rights reserved.
//

import Foundation
import CloverConnector

public class POSStore {
    public var orders = [POSOrder]()
    public var currentOrder:POSOrder? = nil
    public var availableItems = [POSItem]()
    public var preAuths = [POSPayment]()
    public var vaultedCards = [POSCard]()
    public var manualRefunds = [POSNakedRefund]()
    
    fileprivate var storeListeners:NSMutableArray = NSMutableArray()
    fileprivate var orderListeners:NSMutableArray = NSMutableArray()
    
    public var transactionSettings = CLVModels.Payments.TransactionSettings()
    
    public var cardNotPresent:Bool?

    public func newOrder() {
        if let co = currentOrder {
            co.clearListeners();
        }
        currentOrder = POSOrder()
        for listener in orderListeners {
            if let listener = listener as? POSOrderListener {
                currentOrder?.addListener(listener)
            }
        }
        if let currentOrder = currentOrder {
            orders.append(currentOrder);
            for listener in storeListeners {
                (listener as? POSStoreListener)?.newOrderCreated(currentOrder)
            }
        }
        
    }
    
    init() {

        newOrder()
        self.transactionSettings.cardEntryMethods = (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.CARD_ENTRY_METHODS_DEFAULT
    }
    
    public func addStoreListener(_ listener:POSStoreListener) {
        storeListeners.add(listener)
    }
    
    public func removeStoreListener(_ listener:POSStoreListener) {
        storeListeners.remove(listener)
    }
    
    public func addCurrentOrderListener(_ listener:POSOrderListener) {
        orderListeners.add(listener)
        currentOrder?.addListener(listener)
    }
    
    public func removeCurrentOrderListener(_ listener:POSOrderListener) {
        orderListeners.remove(listener)
        currentOrder?.removeListener(listener)
    }
    
    public func addPaymentToOrder(_ payment:POSPayment, order:POSOrder) {
        order.addPayment(payment)
    }
    
    public func addPreAuth(_ payment:POSPayment) {
        preAuths.append(payment)
        for listener in storeListeners {
            (listener as? POSStoreListener)?.preAuthAdded(payment)
        }
    }
    
    public func removePreAuth(_ payment:POSPayment) {
        guard let index = preAuths.index(where: { $0.paymentId == payment.paymentId }) else {
            debugPrint("Couldn't find PreAuth to remove")
            return
        }
        preAuths.remove(at: index)
        for listener in storeListeners {
            (listener as? POSStoreListener)?.preAuthRemoved(payment)
        }
    }
    
    public func addVaultedCard(_ card:POSCard) {
        vaultedCards.append(card)
        for listener in storeListeners {
            (listener as? POSStoreListener)?.vaultCardAdded(card)
        }
    }
    
    public func removeValutedCard(_ card: POSCard) {
        guard let index = vaultedCards.index(where: { $0.first6 == card.first6 && $0.last4 == card.last4 && card.token == card.token}) else { return }
        vaultedCards.remove(at: index)
        for listener in storeListeners {
            (listener as? POSStoreListener)?.vaultCardRemoved(card)
        }
    }
    
    public func addRefundToOrder(_ refund:POSRefund, order:POSOrder) {
        order.addRefund(refund)
        for listener in orderListeners {
            (listener as? POSOrderListener)?.refundAdded(refund)
        }
    }

    public func addManualRefund(_ manualRefund:POSNakedRefund) {
        manualRefunds.append(manualRefund)
        for listener in storeListeners {
            (listener as? POSStoreListener)?.manualRefundAdded(manualRefund)
        }
    }
}

public protocol POSStoreListener:AnyObject {
    func newOrderCreated(_ order:POSOrder)
    func preAuthAdded(_ payment:POSPayment)
    func preAuthRemoved(_ payment:POSPayment)
    func vaultCardAdded(_ card:POSCard)
    func vaultCardRemoved(_ card:POSCard)
    func manualRefundAdded(_ credit:POSNakedRefund)
}