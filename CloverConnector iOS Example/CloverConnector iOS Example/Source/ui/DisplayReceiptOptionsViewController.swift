//  
//  DisplayReceiptOptionsViewController.swift
//  CloverConnector iOS Example
//
//  Copyright © 2019 Clover Network. All rights reserved.
//

import Foundation
import UIKit
import CloverConnector

class DisplayReceiptOptionsViewController: UIViewController {
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var txTypeSegment: UISegmentedControl!
    @IBOutlet var paymentIdTextField: UITextField!
    @IBOutlet var orderIdTextField: UITextField!
    @IBOutlet var refundIdTextField: UITextField!
    @IBOutlet var disablePrintingSwitch: UISwitch!
    @IBOutlet var displayReceiptOptionsButton: UIButton!
    
    /// Transaction that we want to print a receipt for. Usually passed here via segue from the OrdersTableViewController
    public var transaction: POSExchange?
    public var txType: TxType?
    
    /// Segue identifier to navigate to this view controller
    public static let segueId = "showPrintReceiptOptions"
    
    public enum TxType: Int {
        case payment
        case refund
        case credit
    }
    
    var appDelegate: AppDelegate? {
        get {
            return UIApplication.shared.delegate as? AppDelegate
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         In the event that the UI is "compact" (such as for an iPhone), the tabBarController will show a "more" option for extra tabs.
         The "more" tab is a tableView containing the tabs that wouldn't otherwise fit on the tabBar. This includes a UINavigationController
         for subsequently shown UIViewControllers that allows the user to navigate back from a full-screen, modally presented view. On an regular
         width UI (iPad) however, there is enough width and the navigation controller isn't employed. As a result, we add a close button to allow
         the user to dismiss this view. Without it, the user would be stuck on this view without access to a nav bar or the tab bar.
         */
        if self.tabBarController?.moreNavigationController != nil {
            self.closeButton.isHidden = true
        } else {
            self.closeButton.isHidden = false
        }
        
        if self.transaction is POSPayment {
            txType = .payment
        } else if self.transaction is POSRefund {
            txType = .refund
        }
        
        self.txTypeSegment.selectedSegmentIndex = txType?.rawValue ?? 0  //set to the passed-in value, or default to 0
        self.paymentIdTextField.text = self.transaction?.paymentId //set to the passed-in value, if available
        self.refundIdTextField.text = (self.transaction as? POSRefund)?.refundId //set to the passed-in value, if available as a refund
        self.orderIdTextField.text = self.transaction?.orderId //set to the passed-in value, if available
        self.disablePrintingSwitch.isOn = false
        self.displayReceiptOptionsButton.layer.cornerRadius = 5
        
        self.refundIdTextField.isEnabled = (self.txType == .refund)
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func txTypeSegmentChanged(_ sender: UISegmentedControl) {
        guard sender == txTypeSegment else { return }
        
        if let txTypeIndex = TxType(rawValue: txTypeSegment.selectedSegmentIndex) {
            switch txTypeIndex {
            case .payment:
                txType = .payment
                self.refundIdTextField.isEnabled = false
            case .refund:
                txType = .refund
                self.refundIdTextField.isEnabled = true
            case .credit:    //not currently supported by the example app (POSExchange doesn't have a credit subclass type)
                txType = .credit
                self.refundIdTextField.isEnabled = false
            }
        }
    }
    
    @IBAction func displayReceiptOptionsTapped(_ sender: UIButton) {
        let disablePrinting = self.disablePrintingSwitch.isOn
        guard let paymentId = paymentIdTextField.text, paymentId.count > 0 else {
            CCLog.d("Must provide a payment ID")
            return
        }
        guard let orderId = self.orderIdTextField.text, paymentId.count > 0 else {
            CCLog.d("Must provided an order ID")
            return
        }
        
        let request = DisplayReceiptOptionsRequest()
        request.disablePrinting = disablePrinting
        request.orderId = orderId
        request.paymentId = paymentId
        
        if self.transaction is POSRefund {
            guard let refundId = self.refundIdTextField.text, refundId.count > 0 else {
                CCLog.d("Refund type must have a refund ID")
                return
            }
            
            request.refundId = refundId
        }
        
        appDelegate?.cloverConnector?.displayReceiptOptions(request)
    }
}
