//
//  PreAuthViewController.swift
//  CloverConnector
//
//  
//  Copyright © 2018 Clover Network, Inc. All rights reserved.
//

import Foundation
import UIKit
import CloverConnector

public class PreAuthViewController:UIViewController, UITableViewDelegate, UITableViewDataSource
{
    @IBOutlet weak var preAuthAmount: UITextField!
    
    @IBOutlet weak var preAuthButton: UIButton!
    
    @IBOutlet weak var tableView: UITableView!
    
    override public func viewDidAppear(_ animated: Bool) {
        POSStore.shared.addStoreListener(self)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: OperationQueue.main, using: {[weak self] notification in
            guard let self = self else { return }
            if self.preAuthAmount.isFirstResponder {
                self.view.window?.frame.origin.y = -1 * ((notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0)
            }
        })
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: OperationQueue.main, using: {[weak self] notification in
            guard let self = self else { return }
            if self.view.window?.frame.origin.y != 0 {
                self.view.window?.frame.origin.y += ((notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0)
            }
        })
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        POSStore.shared.removeStoreListener(self)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return POSStore.shared.preAuths.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PreAuthTableViewCell.preAuthCellID, for: indexPath) as? PreAuthTableViewCell else {
            return UITableViewCell()
        }
        
        let preAuths = POSStore.shared.preAuths
        
        let thisPreAuth = preAuths[indexPath.row]
        cell.lastFour.text = "x\(thisPreAuth.last4 ?? "----")"
        cell.preAuthName.text = thisPreAuth.name ?? ""
        cell.amount.text = CurrencyUtils.IntToFormat(thisPreAuth.amount) ?? "$ ?.??"
        
        //cleanup in case of cell re-use
        for view in cell.incrementsView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        //If pre-auth has been incremented, list them individually
        if let increments = thisPreAuth.increments, increments.count > 0 {
            cell.incrementLabel.isHidden = false
            
            var totalAuthAmount = thisPreAuth.amount
            var originalAuthAmount = thisPreAuth.amount
            //...then list all of the subsequent increments
            for increment in increments {
                guard let incrementAmount = increment.amount else { continue }
                let label = UILabel()
                label.font.withSize(11)
                label.text = CurrencyUtils.IntToFormat(incrementAmount)
                cell.incrementsView.addArrangedSubview(label)
                
                originalAuthAmount -= incrementAmount
            }
            
            //Make sure the original payment is the first "increment"...
            let originalLabel = UILabel()
            originalLabel.font.withSize(11)
            originalLabel.text = "Original - \(CurrencyUtils.IntToFormat(originalAuthAmount) ?? "$ ?.??")"
            cell.incrementsView.insertArrangedSubview(originalLabel, at: 0)
        } else {
            cell.incrementLabel.isHidden = true
        }
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let cloverConnector = (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector else { return }
        guard let currentOrder = POSStore.shared.currentOrder else { return }
        if indexPath.row >= POSStore.shared.preAuths.count { return }
        let preAuthPayment = POSStore.shared.preAuths[indexPath.row]
        
        let alert = UIAlertController(title: "Pay with PreAuth", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Increment PreAuth", style: .default, handler: { action in
            self.incrementPreAuth(preAuthPayment.paymentId)
        }))
        
        if currentOrder.getTotal() > 0 {
            alert.addAction(UIAlertAction(title: "Pay for Current Order", style: .default, handler: { [weak self] action in
                guard let cpar = self?.generateCPAR(payment: preAuthPayment) else { return }
                cloverConnector.capturePreAuth(cpar)
            }))
            alert.addAction(UIAlertAction(title: "Delete PreAuth", style: .destructive, handler: { action in
                POSStore.shared.removePreAuth(preAuthPayment)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        } else {
            alert.message = "Please create an order to apply to this PreAuth in the Register."
            alert.addAction(UIAlertAction(title: "Delete Pre-Auth", style: .destructive, handler: { action in
                POSStore.shared.removePreAuth(preAuthPayment)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    func generateCPAR(payment:POSPayment) -> CapturePreAuthRequest? {
        guard let currentOrder = POSStore.shared.currentOrder else { return nil }
        let car = CapturePreAuthRequest(amount: currentOrder.getTotal(), paymentId: payment.paymentId)
        car.externalId = payment.externalPaymentId
        car.tipAmount = currentOrder.getTipAmount()
        car.tippableAmount = currentOrder.getTippableAmount()
        car.tipMode = POSStore.shared.transactionSettings.tipMode
        car.autoAcceptsSignature = POSStore.shared.transactionSettings.autoAcceptSignature
        if let cloverShouldHandleReceipts = POSStore.shared.transactionSettings.cloverShouldHandleReceipts {
            car.disablePrinting = !cloverShouldHandleReceipts
        }
        car.signatureEntryLocation = POSStore.shared.transactionSettings.signatureEntryLocation
        car.disableReceiptSelection = POSStore.shared.transactionSettings.disableReceiptSelection
        car.signatureThreshold = POSStore.shared.transactionSettings.signatureThreshold
        return car
    }
    
    @IBAction func onPreAuth(_ sender: UIButton) {
        preAuthAmount.resignFirstResponder()
        
        if let amtText = preAuthAmount.text, let amt:Int = Int(amtText) {
            let externalId = String(arc4random())
            (UIApplication.shared.delegate as? AppDelegate)?.cloverConnectorListener?.preAuthExpectedResponseId = externalId
            let par = PreAuthRequest(amount: amt, externalId: externalId)
            // below are all optional
            if let enablePrinting = POSStore.shared.transactionSettings.cloverShouldHandleReceipts {
                par.disablePrinting = !enablePrinting
            }
            par.disableReceiptSelection = POSStore.shared.transactionSettings.disableReceiptSelection
            par.disableRestartTransactionOnFail = POSStore.shared.transactionSettings.disableRestartTransactionOnFailure
            
            (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.preAuth(par)
        }
    }
    
    private func incrementPreAuth(_ paymentId: String) {
        let incrementAuthAlert = UIAlertController(title: "Increment Pre-auth", message: "By how much would you like to increment the pre-auth?", preferredStyle: .alert)
        incrementAuthAlert.addTextField { (textfield) in
            textfield.placeholder = "Amount to increment"
            textfield.keyboardType = .decimalPad
        }
        incrementAuthAlert.addAction(UIAlertAction(title: "Increment", style: .default, handler: { (action) in
            if let textField = incrementAuthAlert.textFields?.first,
                let value = textField.text {
                guard let numericValue = Int(value) else {
                    return
                }
                
                let ipa = IncrementPreauthRequest(amount: numericValue, paymentId: paymentId)
                (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.incrementPreAuth(ipa)
            }
        }))
        incrementAuthAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(incrementAuthAlert, animated: true, completion: nil)
    }
    
    fileprivate func getKeyboardHeight(_ notification: Notification) -> CGFloat? {
        return (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
    }
}


extension PreAuthViewController : POSStoreListener {
    // POSStoreListener
    public func newOrderCreated(_ order:POSOrder){}
    public func preAuthAdded(_ payment:POSPayment){
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    public func preAuthRemoved(_ payment:POSPayment){
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    public func preAuthUpdated(_ payment: POSPreauth) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    public func vaultCardAdded(_ card:POSCard){}
    public func vaultCardRemoved(_ card:POSCard){}
    public func manualRefundAdded(_ credit:POSNakedRefund){}
    // End POSStoreListener
}

class PreAuthTableViewCell: UITableViewCell {
    static let preAuthCellID = "preauthCellIdentifier"
    
    @IBOutlet weak var lastFour: UILabel!
    @IBOutlet weak var preAuthName: UILabel!
    @IBOutlet weak var amount: UILabel!
    @IBOutlet weak var incrementsView: UIStackView!
    @IBOutlet weak var incrementLabel: UILabel!
}
