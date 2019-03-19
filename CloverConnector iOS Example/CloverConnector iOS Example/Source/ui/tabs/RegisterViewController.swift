//
//  RegisterViewController.swift
//  ExamplePOS
//
//  
//  Copyright © 2017 Clover Network, Inc. All rights reserved.
//

import Foundation
import UIKit
import CloverConnector

class RegisterViewController:UIViewController, POSOrderListener, POSStoreListener, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate{
    
    @IBOutlet weak var currentOrderListItems: UITableView!
    @IBOutlet weak var currentOrderView: UIView!
    @IBOutlet weak var storeView: UIView!
    var startingPoint:CGRect?
    fileprivate var store = POSStore.shared
    @IBOutlet weak var subTotalLabel: UILabel!
    @IBOutlet weak var discountsLabel: UILabel!
    @IBOutlet weak var taxLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var payButton: UIButton!
    
    fileprivate var signatureVerifyRequest:VerifySignatureRequest?
    
    @IBOutlet weak var currentOrderBottomOffset: NSLayoutConstraint!
    @IBOutlet weak var currentOrderHeight: NSLayoutConstraint!
    @IBOutlet weak var storeViewTop: NSLayoutConstraint!
    
    @IBOutlet weak var currentView: UIView!
    @IBOutlet var parentView: UIView!
    
    @IBOutlet var longPressGestureRecognizer: UILongPressGestureRecognizer!
    
    override func viewDidLoad() {
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnectorListener?.viewController = self
        
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(panCurrentOrderView))
        currentOrderView.addGestureRecognizer(dragGesture)
        
        store.addCurrentOrderListener(self)
        store.addStoreListener(self)
        
        startingPoint = currentOrderView.frame
        
        //UILongPressGestureRecognizer(target: currentOrderListItems, action: #selector(handleLongPress))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnectorListener?.viewController = self
    }
    
    @IBAction func longPressHandler(_ sender: UILongPressGestureRecognizer) {
        let cgPoint = sender.location(in: self.currentOrderListItems)
        
        guard let indexPath = currentOrderListItems.indexPathForRow(at: cgPoint) else { return }
        
        if sender.state == UIGestureRecognizer.State.ended {
            if let data = store.currentOrder?.items[indexPath.row] {
                store.currentOrder?.removeLineItem(data)
            }
        }
    }

    
    var startPan:CGPoint?
    var startOffset:CGFloat = 0.0
    
    @objc func panCurrentOrderView(_ sender:UIPanGestureRecognizer) {
        
        
        //var p:CGPoint = currentOrderView.locationInView(parentView)
        var center:CGPoint = CGPoint.zero
        center = sender.location(in: currentOrderView)
        
        
        switch sender.state {
        case .began:
            debugPrint("began")
            let currentLoc = sender.location(in: currentOrderView)
            startPan = sender.location(in: currentOrderView)
            startOffset = self.storeViewTop.constant
            debugPrint("Starting at " + String(describing: currentLoc.x) + ", " + String(describing: currentLoc.y))
        case .changed:
            guard let startPan = self.startPan else { return }
            debugPrint("Changed..")
            debugPrint("Y-Offset: " + String(describing: center.y-startPan.y))
            debugPrint("Center: " + String(describing: startPan.x) + ", " + String(describing: startPan.y))
            let yOffset = center.y-startPan.y
            var currentConstant = self.storeViewTop.constant;
            currentConstant = yOffset + startOffset; // needs to be offset..
            if(currentConstant > self.parentView.frame.height) {
                currentConstant = self.parentView.frame.height
            }
            if(currentConstant < 120) {
                currentConstant = 120
            }
            
            self.storeViewTop.constant = currentConstant
            
        case .ended:
            let lastOffset = self.storeViewTop.constant
            let halfWay = (self.parentView.frame.height - 120) / 2.0 + 120
            if(lastOffset < (halfWay)) {
                // close
                UIView.animate( withDuration: 0.1, animations: {
                    self.storeViewTop.constant = 120
                    self.currentOrderBottomOffset.constant = -500
                    self.parentView.layoutIfNeeded()
                    self.currentView.layoutIfNeeded()
                    
                    debugPrint(String(describing: self.payButton.frame.minX) + " x " + String(describing: self.payButton.frame.minY))
                    debugPrint(String(describing: self.currentOrderView.frame.height))
                    
                    self.payButton.layoutIfNeeded()
                    self.currentView.layoutSubviews()
                })
            } else {
                UIView.animate( withDuration: 0.1, animations: {
                    self.storeViewTop.constant = self.parentView.frame.height
                    self.currentOrderBottomOffset.constant = 0
                    self.parentView.layoutIfNeeded()
                    self.currentView.layoutIfNeeded()
                    
                    debugPrint(String(describing: self.payButton.frame.minX) + " x " + String(describing: self.payButton.frame.minY))
                    debugPrint(String(describing: self.currentOrderView.frame.height))
                    
                    self.payButton.layoutIfNeeded()
                    self.currentView.layoutSubviews()
                })
            }
        case .cancelled:
            debugPrint("cancelled")
        case .failed:
            debugPrint("failed")
        default:
            debugPrint("Default")
        }
    }
    
    //store a human readable copy of the order for use in sending to the CloverDevice
    var currentDisplayOrder:DisplayOrder = DisplayOrder()
    
    // POSOrderListener
    func itemAdded(_ item:POSLineItem) {
        guard let itemName = item.item.name, let formattedItemPrice = CurrencyUtils.IntToFormat(item.item.price) else { return }
        
        let displayLineItem = DisplayLineItem(id: item.item.id, name:itemName, price: formattedItemPrice, quantity: String(item.quantity))
        currentDisplayOrder.lineItems.append(displayLineItem)

        updateTotals()
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.showDisplayOrder(currentDisplayOrder)
    }
    
    func itemRemoved(_ item:POSLineItem) {
        if let index = currentDisplayOrder.lineItems.index(where: { $0.id == item.item.id }) {
            currentDisplayOrder.lineItems.remove(at: index)
        }
        
        updateTotals()
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.showDisplayOrder(currentDisplayOrder)
    }
    
    func itemModified(_ item:POSLineItem) {
        if let index = currentDisplayOrder.lineItems.index(where: { $0.id == item.item.id }) {
            let displayLineItem = currentDisplayOrder.lineItems[index]
            displayLineItem.quantity = String(item.quantity)
            displayLineItem.name = item.item.name
            displayLineItem.price = CurrencyUtils.IntToFormat(item.item.price)
        }
        
        updateTotals()
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.showDisplayOrder(currentDisplayOrder)
    }
    
    func discountAdded(_ item:POSDiscount) {
        updateTotals()
    }
    func paymentAdded(_ item:POSPayment) {
        updateTotals()
    }
    func refundAdded(_ refund: POSRefund) {
        updateTotals()
    }
    func paymentChanged(_ item:POSPayment) {
        updateTotals()
    }
    // POSOrderListener.End
    
    // POSStoreListener
    func newOrderCreated(_ order:POSOrder) {
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.removeDisplayOrder(currentDisplayOrder)
        currentDisplayOrder = DisplayOrder()
        currentDisplayOrder.id = String(arc4random())
        DispatchQueue.main.async { [unowned self] in
            self.currentOrderListItems.reloadData()
        }
        updateTotals()
    }
    
    func preAuthAdded(_ payment: POSPayment) {
        // not needed in register
    }
    
    func preAuthRemoved(_ payment: POSPayment) {
        // not needed in register
    }
    
    func vaultCardAdded(_ card: POSCard) {
        // not needed in register
    }
    
    func vaultCardRemoved(_ card: POSCard) {
        // not needed in register
    }
    
    func manualRefundAdded(_ credit: POSNakedRefund) {
        // not needed in register
    }
    // POSStoreListener.End
    
    
    func updateTotals() {
        if let currentOrder = store.currentOrder {
            DispatchQueue.main.async{ [unowned self] in
                self.subTotalLabel.text = CurrencyUtils.IntToFormat(currentOrder.getSubtotal())
                self.taxLabel.text = CurrencyUtils.IntToFormat(currentOrder.getTaxAmount())
                self.totalLabel.text = CurrencyUtils.IntToFormat(currentOrder.getTotal())
                
                self.currentOrderListItems.reloadData()
            }
            
            // update DisplayOrder..
            self.currentDisplayOrder.total = CurrencyUtils.IntToFormat(currentOrder.getTotal())
            self.currentDisplayOrder.subtotal = CurrencyUtils.IntToFormat(currentOrder.getSubtotal())
            self.currentDisplayOrder.tax = CurrencyUtils.IntToFormat(currentOrder.getTaxAmount())
        }
    }
    
    // TableView
    
    
    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let currentOrder = store.currentOrder {
            if indexPath.row < currentOrder.items.count {
                let data = currentOrder.items[indexPath.row]
                
                if let cell:CurrentOrderListItemTableCell = tv.dequeueReusableCell( withIdentifier: "OrderItemCell", for: indexPath) as? CurrentOrderListItemTableCell {
                    cell.item = data
                    return cell
                }
            }
        }

        return tv.dequeueReusableCell( withIdentifier: "OrderItemCell", for: indexPath)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return store.currentOrder?.items.count ?? 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    // Collection View
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return store.availableItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell:UICollectionViewCell = collectionView.dequeueReusableCell( withReuseIdentifier: "AvailableItemCell", for: indexPath)
        
        if let cell = cell as? AvailableItemCollectionViewCell {
            cell.item = store.availableItems[indexPath.row]
        }
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        store.currentOrder?.addLineItem(POSLineItem(item: store.availableItems[(indexPath as IndexPath).row]))
        //currentOrderListItems.reloadData()
    }
    

    /*func collectionView(_:layout:sizeForItemAtIndexPath:NSIndexPath) {
    
    }*/
    
    func verifySignature(_ signatureVerifyRequest:VerifySignatureRequest) {
        self.signatureVerifyRequest = signatureVerifyRequest
        self.performSegue( withIdentifier: "ShowSignature", sender: self)
//        ivc.showViewController(SignatureViewController(), sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as? SignatureViewController)?.signatureVerifyRequest = self.signatureVerifyRequest
    }
    
    @IBAction func saleButtonClicked(_ sender: UIButton) {
        guard let currentOrder = store.currentOrder else { return }
        guard let cloverConnector = (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector else { return }
        
        currentOrder.pendingPaymentId = String(arc4random())
        let sr = SaleRequest(amount:currentOrder.getTotal(), externalId: currentOrder.pendingPaymentId!)
        // below are all optional
        sr.allowOfflinePayment = store.transactionSettings.allowOfflinePayment
        sr.approveOfflinePaymentWithoutPrompt = store.transactionSettings.approveOfflinePaymentWithoutPrompt
        sr.autoAcceptSignature = store.transactionSettings.autoAcceptSignature
        sr.autoAcceptPaymentConfirmations = store.transactionSettings.autoAcceptPaymentConfirmations
        sr.cardEntryMethods = store.transactionSettings.cardEntryMethods ?? cloverConnector.CARD_ENTRY_METHODS_DEFAULT
        sr.disableCashback = store.transactionSettings.disableCashBack
        sr.disableDuplicateChecking = store.transactionSettings.disableDuplicateCheck
        if let enablePrinting = store.transactionSettings.cloverShouldHandleReceipts {
            sr.disablePrinting = !enablePrinting
        }
        sr.disableReceiptSelection = store.transactionSettings.disableReceiptSelection
        sr.disableRestartTransactionOnFail = store.transactionSettings.disableRestartTransactionOnFailure
        
        if let txTipModeString = store.transactionSettings.tipMode?.rawValue,
            let srTipMode = SaleRequest.TipMode(rawValue: txTipModeString) {
            sr.tipMode = srTipMode
        }
        
        sr.tipSuggestions = store.transactionSettings.tipSuggestions
        
        sr.forceOfflinePayment = store.transactionSettings.forceOfflinePayment
        sr.cardNotPresent = store.cardNotPresent
        
        sr.tipAmount = nil
        sr.tippableAmount = currentOrder.getTippableAmount()
        sr.tipMode = SaleRequest.TipMode.ON_SCREEN_BEFORE_PAYMENT
        
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.sale(sr)
    }
    
    @IBAction func authButtonClicked(_ sender: UIButton) {
        guard let currentOrder = store.currentOrder else { return }
        guard let cloverConnector = (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector else { return }
        currentOrder.pendingPaymentId = String(arc4random())
        
        let ar = AuthRequest(amount: currentOrder.getTotal(), externalId: currentOrder.pendingPaymentId!)
        // below are all optional
        ar.allowOfflinePayment = store.transactionSettings.allowOfflinePayment
        ar.approveOfflinePaymentWithoutPrompt = store.transactionSettings.approveOfflinePaymentWithoutPrompt
        ar.autoAcceptSignature = store.transactionSettings.autoAcceptSignature
        ar.autoAcceptPaymentConfirmations = store.transactionSettings.autoAcceptPaymentConfirmations
        ar.cardEntryMethods = store.transactionSettings.cardEntryMethods ?? cloverConnector.CARD_ENTRY_METHODS_DEFAULT
        ar.disableCashback = store.transactionSettings.disableCashBack
        ar.disableDuplicateChecking = store.transactionSettings.disableDuplicateCheck
        if let enablePrinting = store.transactionSettings.cloverShouldHandleReceipts {
            ar.disablePrinting = !enablePrinting
        }
        ar.disableReceiptSelection = store.transactionSettings.disableReceiptSelection
        ar.disableRestartTransactionOnFail = store.transactionSettings.disableRestartTransactionOnFailure
        
        ar.forceOfflinePayment = store.transactionSettings.forceOfflinePayment
        ar.cardNotPresent = store.cardNotPresent
        
        ar.tippableAmount = currentOrder.getTippableAmount()
        ar.tipSuggestions = store.transactionSettings.tipSuggestions
        
        (UIApplication.shared.delegate as? AppDelegate)?.cloverConnector?.auth(ar)
    }
    
    @IBAction func newOrderButtonClicked(_ sender: UIButton) {
        store.newOrder()
        updateTotals()
    }
}
