//
//  ManualRefundViewController.swift
//  CloverConnector
//
//  
//  Copyright © 2017 Clover Network, Inc. All rights reserved.
//

import Foundation
import UIKit
import CloverConnector

class ManualRefundViewController:UIViewController, UITableViewDelegate, UITableViewDataSource
{
    @IBOutlet weak var refundAmount: UITextField!
    
    @IBOutlet weak var refundButton: UIButton!
    @IBOutlet weak var manualRefundsTable: UITableView!
    
    let store = POSStore.shared
    
    override func viewDidAppear(_ animated: Bool) {
        store.addStoreListener(self)
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: OperationQueue.main, using: {[weak self] notification in
            guard let self = self else { return }
            if self.refundAmount.isFirstResponder {
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
    
    override func viewDidDisappear(_ animated: Bool) {
        store.removeStoreListener(self)
        
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @IBAction func onManualRefund(_ sender: UIButton) {
        refundAmount.resignFirstResponder()
        
        if let amtText = refundAmount.text, let amt:Int = Int(amtText) {
            let request = ManualRefundRequest(amount: amt, externalId: String(arc4random()))
            (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.manualRefund(request)
        }
    }
    
    fileprivate func getKeyboardHeight(_ notification: Notification) -> CGFloat? {
        return (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return store.manualRefunds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell =  manualRefundsTable.dequeueReusableCell(withIdentifier: "MRCell")
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "MRCell")
        }
        
        let refunds = store.manualRefunds
        if indexPath.row < refunds.count {
            cell?.textLabel?.text = CurrencyUtils.IntToFormat(refunds[indexPath.row].amount) ?? "$ ?.??"
        } else {
            cell?.textLabel?.text = "UNKNOWN"
        }
        
        return cell ?? UITableViewCell()
    }
}

extension ManualRefundViewController : POSStoreListener {
    // POSStoreListener
    func newOrderCreated(_ order:POSOrder){}
    func preAuthAdded(_ payment:POSPayment){}
    func preAuthRemoved(_ payment:POSPayment){}
    func vaultCardAdded(_ card:POSCard){}
    func vaultCardRemoved(_ card:POSCard){}
    func manualRefundAdded(_ credit:POSNakedRefund){
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                self.manualRefundsTable.reloadData()
            })
        }
    }
    // End POSStoreListener
}
