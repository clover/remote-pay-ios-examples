//
//  VaultCardViewController.swift
//  CloverConnector
//
//  
//  Copyright © 2017 Clover Network, Inc. All rights reserved.
//

import Foundation
import UIKit
import CloverConnector

public class VaultCardViewController:UIViewController, UITableViewDataSource, UITableViewDelegate
{
    
    @IBOutlet weak var tableView: UITableView!
    let store = POSStore.shared
    
    public override func viewDidLoad() {
    }
    
    deinit {
        
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        store.addStoreListener(self)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        store.removeStoreListener(self)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return store.vaultedCards.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //        let cell:UITableViewCell = manualRefundsTable.dequeueReusableCellWithIdentifier(withIdentifier: "ManualRefundCell")
        
        var cell =  tableView.dequeueReusableCell(withIdentifier: "VCCell")
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "VCCell")
        }
        
        let vals = store.vaultedCards
        if indexPath.row < vals.count { 
            let card = vals[indexPath.row]
            
            cell?.textLabel?.text = (card.first6) + "-XXXXXX-" + (card.last4)
            cell?.detailTextLabel?.text = card.token ?? "---"
        } else {
            cell?.textLabel?.text = "UNKNOWN"
            cell?.detailTextLabel?.text = ""
        }
        
        return cell ?? UITableViewCell()
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let cloverConnector = (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector else { return }
        guard let currentOrder = store.currentOrder else { return }
        guard indexPath.row < store.vaultedCards.count else { return }
        let vaultedPOSCard = store.vaultedCards[indexPath.row]
        
        let alert = UIAlertController(title: "Pay with Vaulted Card", message: nil, preferredStyle: .alert)
        if currentOrder.getTotal() > 0 {
            alert.addAction(UIAlertAction(title: "Pay for Current Order (Sale)", style: .default, handler: { action in
                currentOrder.pendingPaymentId = String(arc4random())
                let saleRequest = SaleRequest(amount: currentOrder.getTotal(), externalId: currentOrder.pendingPaymentId!)
                saleRequest.vaultedCard = vaultedPOSCard.vaultedCard
                // below are all optional
                saleRequest.allowOfflinePayment = self.store.transactionSettings.allowOfflinePayment
                saleRequest.approveOfflinePaymentWithoutPrompt = self.store.transactionSettings.approveOfflinePaymentWithoutPrompt
                saleRequest.autoAcceptSignature = self.store.transactionSettings.autoAcceptSignature
                saleRequest.autoAcceptPaymentConfirmations = self.store.transactionSettings.autoAcceptPaymentConfirmations
                saleRequest.cardEntryMethods = self.store.transactionSettings.cardEntryMethods ?? cloverConnector.CARD_ENTRY_METHODS_DEFAULT
                saleRequest.disableCashback = self.store.transactionSettings.disableCashBack
                saleRequest.disableDuplicateChecking = self.store.transactionSettings.disableDuplicateCheck
                if let enablePrinting = self.store.transactionSettings.cloverShouldHandleReceipts {
                    saleRequest.disablePrinting = !enablePrinting
                }
                saleRequest.disableReceiptSelection = self.store.transactionSettings.disableReceiptSelection
                saleRequest.disableRestartTransactionOnFail = self.store.transactionSettings.disableRestartTransactionOnFailure
                
                if let txTipModeString = self.store.transactionSettings.tipMode?.rawValue,
                    let srTipMode = SaleRequest.TipMode(rawValue: txTipModeString) {
                    saleRequest.tipMode = srTipMode
                }
                
                saleRequest.forceOfflinePayment = self.store.transactionSettings.forceOfflinePayment
                saleRequest.cardNotPresent = self.store.cardNotPresent
                
                saleRequest.tipAmount = nil
                saleRequest.tippableAmount = currentOrder.getTippableAmount()
                saleRequest.tipMode = SaleRequest.TipMode.ON_SCREEN_BEFORE_PAYMENT
                
                cloverConnector.sale(saleRequest)
            }))
            alert.addAction(UIAlertAction(title: "Pay for Current Order (Auth)", style: .default, handler: { action in
                currentOrder.pendingPaymentId = String(arc4random())
                let authRequest = AuthRequest(amount: currentOrder.getTotal(), externalId: currentOrder.pendingPaymentId!)
                authRequest.vaultedCard = vaultedPOSCard.vaultedCard
                // below are all optional
                authRequest.allowOfflinePayment = self.store.transactionSettings.allowOfflinePayment
                authRequest.approveOfflinePaymentWithoutPrompt = self.store.transactionSettings.approveOfflinePaymentWithoutPrompt
                authRequest.autoAcceptSignature = self.store.transactionSettings.autoAcceptSignature
                authRequest.autoAcceptPaymentConfirmations = self.store.transactionSettings.autoAcceptPaymentConfirmations
                authRequest.cardEntryMethods = self.store.transactionSettings.cardEntryMethods ?? cloverConnector.CARD_ENTRY_METHODS_DEFAULT
                authRequest.disableCashback = self.store.transactionSettings.disableCashBack
                authRequest.disableDuplicateChecking = self.store.transactionSettings.disableDuplicateCheck
                if let enablePrinting = self.store.transactionSettings.cloverShouldHandleReceipts {
                    authRequest.disablePrinting = !enablePrinting
                }
                authRequest.disableReceiptSelection = self.store.transactionSettings.disableReceiptSelection
                authRequest.disableRestartTransactionOnFail = self.store.transactionSettings.disableRestartTransactionOnFailure
                
                authRequest.forceOfflinePayment = self.store.transactionSettings.forceOfflinePayment
                authRequest.cardNotPresent = self.store.cardNotPresent
                
                authRequest.tippableAmount = currentOrder.getTippableAmount()
                
                cloverConnector.auth(authRequest)
            }))
            alert.addAction(UIAlertAction(title: "Delete Vaulted Card", style: .destructive, handler: { action in
                self.store.removeValutedCard(vaultedPOSCard)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        } else {
            alert.message = "Please create an order to apply to this Vaulted Card in the Register."
            alert.addAction(UIAlertAction(title: "Delete Vaulted Card", style: .destructive, handler: { action in
                self.store.removeValutedCard(vaultedPOSCard)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func onVaultCard(_ sender: UIButton) {
        tableView.becomeFirstResponder()
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.vaultCard(VaultCardRequest())
    }
}


extension VaultCardViewController : POSStoreListener {
    // POSStoreListener
    public func newOrderCreated(_ order:POSOrder){}
    public func preAuthAdded(_ payment:POSPayment){
    }
    public func preAuthRemoved(_ payment:POSPayment){}
    public func preAuthUpdated(_ payment: POSPreauth) {}
    public func vaultCardAdded(_ card:POSCard){
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
            self.tableView.reloadData()
        })
    }
    public func vaultCardRemoved(_ card: POSCard) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
            self.tableView.reloadData()
        })
    }
    public func manualRefundAdded(_ credit:POSNakedRefund){}
    // End POSStoreListener
}
