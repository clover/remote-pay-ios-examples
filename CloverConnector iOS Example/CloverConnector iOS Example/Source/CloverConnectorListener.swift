//
//  CloverConnectorListener.swift
//  CloverConnector
//
//  
//  Copyright © 2018 Clover Network, Inc. All rights reserved.
//

import Foundation
import UIKit
import CloverConnector

public class CloverConnectorListener : NSObject, ICloverConnectorListener, UIAlertViewDelegate {
    
    weak var cloverConnector:ICloverConnector?
    
    /// View Controller being displayed, used to present alert view controllers
    weak var viewController:UIViewController?
    fileprivate var lastDeviceEvent:CloverDeviceEvent?
    
    public var preAuthExpectedResponseId:String?
    
    
    fileprivate var ready:Bool = false
    fileprivate var suppressConnectionErrors = false //since connection errors could conceivably occur every few seconds, use this to suppress them after the first has been shown
    public var getPrintersCallback: ((_ response:RetrievePrintersResponse) -> Void)? //used in the MiscVC to allow the user to select which printer to test on. See: onRetrievePrintersResponse below
    
    /// Dict used in the PrintTestVC to allow the UI to respond to print status. It is the responsibility of the caller to clean up its closure once done. See: onPrintJobStatusResponse below.
    public var printJobStatusDict = [String : (PrintJobStatusResponse) -> Void]()
    
    public init(cloverConnector:ICloverConnector){
        self.cloverConnector = cloverConnector
    }
    
    fileprivate var store = POSStore.shared
    
    // MARK: - User Messaging

    /// Displays a simple popup message with no buttons, similar to an Android Toast.
    ///
    /// - Parameter message: The message to display.  Will be shown as the only text in the message
    /// - Parameter duration: The duration to display the message in seconds.  Defaults to 3 seconds, must be > 0 seconds
    /// - Parameter afterShow: A closure to run following the successful display of the message
    /// - Parameter afterDismiss: A closer to run following the successful dismiss of the message
    func showMessage(_ message:String, duration:Double = 3, afterShow: (()->Void)? = nil, afterDismiss: (()->Void)? = nil) {
        guard duration > 0 else { return }
        print("MESSAGE ====> \(message)")
        showMessageWithOptions(message: message, dismissAfter: duration, inputOptions: nil, completion: afterShow, afterDismiss: afterDismiss)
    }
    /// Displays a device event change, typically used for announcing state changes on the Clover Device.
    /// The event's message and input options will be used to populate an Alert Controller.  Upon activation
    /// of an input option, the option's keystroke will be sent back to the Clover Device.
    ///
    /// - Parameter deviceEvent: The event to display.
    fileprivate func showMessageWithEvent(deviceEvent: CloverDeviceEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.lastDeviceEvent = deviceEvent
            self?.showMessageWithOptions(message: deviceEvent.message ?? "", dismissAfter: nil, inputOptions: deviceEvent.inputOptions)
        }
    }
    /// Displays a message to the user, typically used for gathering user input.
    ///
    /// - Parameter title: (Optional) The title to display.  Will be bold at the top of the message.  Defaults to nil, resulting in a blank title on the message.
    /// - Parameter message:  The message to display.  Will be in system font between the title and any buttons.
    /// - Parameter dismissAfter:  (Optional) After this time, the message will be automatically dismissed without user action
    /// - Parameter inputOptions:  (Optional) [InputOption] to be displayed to the user.  Upon activation, the keypress defined in the object will be sent back to the Clover Device
    /// - Parameter alertActions:  (Optional) [UIAlertAction] to be displayed to the user.  Upon activation, the closure defined in the object will be executed
    /// - Parameter completion:  (Optional) Will be executed upon successful display of the message.
    fileprivate func showMessageWithOptions(title:String? = nil, message:String, dismissAfter:Double? = nil, inputOptions:[InputOption]? = nil, alertActions:[UIAlertAction]? = nil, completion: (()->Void)? = nil, afterDismiss: (()->Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            if let alertController = self?.viewController?.presentedViewController as? UIAlertController {
                // have an alert already being presented, so deal with it first
                if alertController.title == message {
                    // same message, no need to re-display
                    return
                } else {
                    // new message, close the old one without animation, then re-call this function
                    if !alertController.isBeingDismissed && !alertController.isBeingPresented {
                        alertController.dismiss(animated: false, completion: { [weak self] in
                            self?.showMessageWithOptions(message: message, dismissAfter: dismissAfter, inputOptions: inputOptions, alertActions:alertActions, completion: completion, afterDismiss: afterDismiss)
                        })
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01, execute: {
                            self?.showMessageWithOptions(message: message, dismissAfter: dismissAfter, inputOptions: inputOptions, alertActions:alertActions, completion: completion, afterDismiss: afterDismiss)
                        })
                    }
                }
            } else {
                // nothing being presented, so let's go ahead and present  (NOTE - we're assuming that only UIAlertController will ever be presented here... so don't go presenting something else)
                let alertController = UIAlertController(title: title ?? "", message: message, preferredStyle: .alert)
                if let inputOptions = inputOptions {
                    for inputOpt in inputOptions {
                        alertController.addAction(UIAlertAction(title: inputOpt.description, style: .default, handler: { [weak self] action in
                            self?.cloverConnector?.invokeInputOption(inputOpt)
                        }))
                    }
                }
                if let alertActions = alertActions {
                    for alertAct in alertActions {
                        alertController.addAction(alertAct)
                    }
                }
                self?.viewController?.present(alertController, animated: false, completion: completion)
                if let dismissAfter = dismissAfter {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + dismissAfter, execute: {[weak self] in
                        if let presentedViewController = self?.viewController?.presentedViewController as? UIAlertController {
                            if presentedViewController.message == alertController.message && presentedViewController.title == alertController.title {
                                presentedViewController.dismiss(animated: false, completion: afterDismiss)
                            }
                        }
                    })
                }
            }
        }
    }
    
    
    // MARK: - ICloverConnectorListener Functions
    
    /*
     * Response to a sale request.
     */
    public func  onSaleResponse ( _ response:SaleResponse ) -> Void {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
           
            guard response.success else {
                if response.result == .CANCEL {
                    self.showMessage("Sale Canceled")
                } else if response.result == .FAIL {
                    self.showMessage("Sale Tx Failed")
                } else {
                    self.showMessage(response.result.rawValue);
                }
                return
            }
            
            guard let order = self.store.currentOrder, let payment = response.payment else {
                //make sure we were expecting a payment for an order and that the response had a valid payment
                return
            }
            
            guard order.pendingPaymentId == payment.externalPaymentId else {
                self.showMessage("External Payment Ids do not match")
                return
            }
            
            if let paymentId = payment.id,
                let orderId = payment.order?.id,
                let paymentAmount = payment.amount {
                let tipAmount = payment.tipAmount ?? 0
                let cashback = payment.cashbackAmount ?? 0
                let posPayment:POSPayment = POSPayment(paymentId: paymentId, externalPaymentId: payment.externalPaymentId, orderId: orderId, employeeId: "DFLTEMPLYEE", amount: paymentAmount, tipAmount: tipAmount, cashbackAmount: cashback, last4: payment.cardTransaction?.last4, name: payment.cardTransaction?.cardholderName)
                
                //if the SaleResponse had additional charges, make sure they're translated to the POSPayment
                if let additionalCharges = payment.additionalCharges?.elements {
                    var posAdditionalCharges = [POSAdditionalChargeAmount]()
                    
                    for additionalCharge in additionalCharges {
                        posAdditionalCharges.append(POSAdditionalChargeAmount(id: additionalCharge.id, amount: additionalCharge.amount, rate: additionalCharge.rate))
                    }
                    
                    posPayment.additionalCharges = posAdditionalCharges
                }
                
                posPayment.status = response.isSale ? PaymentStatus.PAID : (response.isAuth ? PaymentStatus.AUTHORIZED : (response.isPreAuth ? PaymentStatus.PREAUTHORIZED : PaymentStatus.UNKNOWN))
                
                self.store.addPaymentToOrder(posPayment, order: order)
                self.store.newOrder()
                
                self.cloverConnector?.showWelcomeScreen()
                self.showMessage("Sale successfully processed")
            }
        }
    }
    
    /*
     * Response to an auth request
     */
    public func onAuthResponse(_ authResponse: AuthResponse) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard authResponse.success else {
                if authResponse.result == .CANCEL {
                    self.showMessage("Sale Canceled")
                } else if authResponse.result == .FAIL {
                    self.showMessage("Sale Tx Failed")
                } else {
                    self.showMessage(authResponse.result.rawValue);
                }
                return
            }
            
            guard let order = self.store.currentOrder, let payment = authResponse.payment else {
                //make sure we were expecting a payment for an order and that the response had a valid payment
                return
            }
            
            guard order.pendingPaymentId == payment.externalPaymentId else {
                self.showMessage("External Payment Ids do not match")
                return
            }
            
            if let paymentId = payment.id,
                let orderId = payment.order?.id,
                let paymentAmount = payment.amount {
                let tipAmount = payment.tipAmount ?? 0
                let cashback = payment.cashbackAmount ?? 0
                let posPayment:POSPayment = POSPayment(paymentId: paymentId, externalPaymentId: payment.externalPaymentId, orderId: orderId, employeeId: "DFLTEMPLYEE", amount: paymentAmount, tipAmount: tipAmount, cashbackAmount: cashback, last4: payment.cardTransaction?.last4, name: payment.cardTransaction?.cardholderName)
                
                //if the AuthResponse had additional charges, make sure they're translated to the POSPayment
                if let additionalCharges = payment.additionalCharges?.elements {
                    var posAdditionalCharges = [POSAdditionalChargeAmount]()
                    
                    for additionalCharge in additionalCharges {
                        posAdditionalCharges.append(POSAdditionalChargeAmount(id: additionalCharge.id, amount: additionalCharge.amount, rate: additionalCharge.rate))
                    }
                    
                    posPayment.additionalCharges = posAdditionalCharges
                }
                
                posPayment.status = authResponse.isSale ? PaymentStatus.PAID : (authResponse.isAuth ? PaymentStatus.AUTHORIZED : (authResponse.isPreAuth ? PaymentStatus.PREAUTHORIZED : PaymentStatus.UNKNOWN))
                
                self.store.addPaymentToOrder(posPayment, order: order)
                self.store.newOrder()
                
                self.cloverConnector?.showWelcomeScreen()
                self.showMessage("Sale successfully processed")
            }
        }
    }
    
    /*
     * response to a pre-auth request
     */
    public func onPreAuthResponse(_ preAuthResponse: PreAuthResponse) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard preAuthResponse.success else {
                if preAuthResponse.result == .CANCEL {
                    self.showMessage("Sale Canceled")
                } else if preAuthResponse.result == .FAIL {
                    self.showMessage("Sale Tx Failed")
                } else {
                    self.showMessage(preAuthResponse.result.rawValue);
                }
                return
            }
            
            guard let order = self.store.currentOrder, let payment = preAuthResponse.payment else {
                //make sure we were expecting a payment for an order and that the response had a valid payment
                return
            }
            
            guard self.preAuthExpectedResponseId == payment.externalPaymentId else {
                self.showMessage("External Payment Ids do not match")
                return
            }
            
            if let paymentId = payment.id,
                let orderId = payment.order?.id,
                let paymentAmount = payment.amount {
                let tipAmount = payment.tipAmount ?? 0
                let cashback = payment.cashbackAmount ?? 0
                
                let posPreauth:POSPreauth = POSPreauth(paymentId: paymentId, externalPaymentId: payment.externalPaymentId, orderId: orderId, employeeId: "DFLTEMPLYEE", amount: paymentAmount, tipAmount: tipAmount, cashbackAmount: cashback, last4: payment.cardTransaction?.last4, name: payment.cardTransaction?.cardholderName)
                posPreauth.status = preAuthResponse.isSale ? PaymentStatus.PAID : (preAuthResponse.isAuth ? PaymentStatus.AUTHORIZED : (preAuthResponse.isPreAuth ? PaymentStatus.PREAUTHORIZED : PaymentStatus.UNKNOWN))
                posPreauth.increments = payment.increments
                
                self.store.addPreAuth(posPreauth)
                
                self.preAuthExpectedResponseId = nil
                self.cloverConnector?.showWelcomeScreen()
            }
        }
    }
    
    
    /*
     * Response to a preauth being captured.
     */
    public func  onCapturePreAuthResponse ( _ response:CapturePreAuthResponse ) -> Void {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard response.success == true else {
                let responseResult = response.result.rawValue
                let responseReason = response.reason ?? ""
                self.showMessage("PreAuth Capture Error: Payment failed with response code = " + responseResult + " and reason: " + responseReason)
                return
            }
            guard let currentOrder = self.store.currentOrder else {
                self.showMessage("No Current Order!")
                return
            }
            guard let responseAmount = response.amount else {
                self.showMessage("Response Amount is nil!")
                return
            }
            
            // find the preauth in our records
            guard let payment = self.store.preAuths.first( where: {$0.paymentId == response.paymentId }) else {
                self.showMessage("Received PreAuth Capture for a PreAuth Not On Record")
                return
            }

            // remove the preAuth from the active preauth records
            self.store.removePreAuth(payment)
            // add the payment to the order, set the status, and set the amount to the captured amount
            self.store.addPaymentToOrder(payment, order: currentOrder)
            payment.status = PaymentStatus.AUTHORIZED
            payment.amount = responseAmount
            
            self.showMessage("Sale successful processing using Pre Authorization")
            
            // clear the order
            self.store.newOrder()
            self.cloverConnector?.showWelcomeScreen()
            
        }
    }
    
    /*
     * Called in response to an `incrementPreAuth()` call on the CloverConnector
     */
    public func onIncrementPreAuthResponse(_ incrementPreAuthResponse: IncrementPreauthResponse ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if incrementPreAuthResponse.success {
                self.showMessage("Pre-auth successfully incremented")
                
                if let payment = incrementPreAuthResponse.authorization?.payment,
                    let paymentId = payment.id,
                    let orderId = payment.order?.id,
                    let paymentAmount = payment.amount,
                    let increments = payment.increments {
                    let posPreauth = POSPreauth(paymentId: paymentId,
                                                externalPaymentId: payment.externalPaymentId,
                                                orderId: orderId,
                                                employeeId: "DFLTEMPLYEE",
                                                amount: paymentAmount,
                                                tipAmount: payment.tipAmount ?? 0,
                                                cashbackAmount: payment.cashbackAmount ?? 0,
                                                last4: payment.cardTransaction?.last4,
                                                name: payment.cardTransaction?.cardholderName)
                    posPreauth.increments = increments
                    self.store.updatePreAuth(posPreauth)
                }
            } else {
                self.showMessage(incrementPreAuthResponse.reason ?? "")
            }
        }
    }
    
    /*
     * Response to a tip adjustment for an auth.
     */
    public func  onTipAdjustAuthResponse ( _ response:TipAdjustAuthResponse ) -> Void {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if response.success {
                var updatedTip = false
                for order in self.store.orders {
                    for exchange in order.payments {
                        if exchange.paymentId == response.paymentId {
                            exchange.tipAmount = response.tipAmount
                            updatedTip = true;
                            // TODO: update the table
                            break;
                        }
                    }
                }
                if (updatedTip) {
                    self.showMessage("Tip successfully adjusted")
                }
            } else {
                self.showMessage("Tip adjust failed")
            }
        }
    }
    
    
    /*
     * Response to a payment be voided.
     */
    public func  onVoidPaymentResponse ( _ response:VoidPaymentResponse ) -> Void {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if response.success {
                var done = false;
                for order in self.store.orders {
                    for payment in order.payments {
                        if payment.paymentId == response.paymentId {
                            payment.status = .VOIDED
                            self.showMessage("Payment was voided")
                            done = true;
                            break;
                        }
                    }
                    if (done) {
                        break;
                    }
                }
            } else {
                self.showMessage("There was an error voiding payment: " + String(describing: response.result))
            }
        }
    }

    
    
    /*
     * Response to an amount being refunded.
     */
    public func  onManualRefundResponse ( _ manualRefundResponse:ManualRefundResponse ) -> Void {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if manualRefundResponse.success {
                if let amt = manualRefundResponse.credit?.amount {
                    let nakedRefund = POSNakedRefund(employeeId:"DFLTEMPLYE", amount: amt)
                    self.store.addManualRefund(nakedRefund)
                    self.showMessage("Manual Refund Successfully Processed")
                    self.cloverConnector?.showWelcomeScreen()
                }
            } else {
                if manualRefundResponse.result == .CANCEL {
                    self.showMessage("Manual Refund Canceled")
                } else if manualRefundResponse.result == .FAIL {
                    self.showMessage("Manual Refund failed")
                } else {
                    self.showMessage(manualRefundResponse.result.rawValue)
                }
            }
        }
    }
    
    
    /*
     * Response to a closeout.
     */
    public func  onCloseoutResponse ( _ response:CloseoutResponse ) -> Void {
        DispatchQueue.main.async { [weak self] in
            if response.success {
                self?.showMessage("Closeout complete for batch: " + (response.batch?.id ?? ""))
            } else {
                self?.showMessage("Error scheduling closeout: " + (response.reason ?? ""))
            }
        }
    }
    
    
    /*
     * Receives signature verification requests.
     */
    public func  onVerifySignatureRequest ( _ signatureVerifyRequest:VerifySignatureRequest ) -> Void {
        DispatchQueue.main.async{ [weak self] in

            if var topViewController = (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController {
                while let presentedViewController = topViewController.presentedViewController {
                    topViewController = presentedViewController
                }
                if let tvc = topViewController as? TabBarController, let rvc = tvc.selectedViewController as? RegisterViewController {
                    // in the register, we'll present the verify signature view using the RegisterViewController
                    rvc.verifySignature(signatureVerifyRequest)
                } else {
                    // anywhere else, we'll just ask for verification
                    var alertActions = [UIAlertAction]()
                    alertActions.append(UIAlertAction(title: "Accept", style: .cancel, handler: {[weak self] action in
                        self?.cloverConnector?.acceptSignature(signatureVerifyRequest)
                    }))
                    alertActions.append(UIAlertAction(title: "Reject", style: .default, handler: {[weak self] action in
                        self?.cloverConnector?.rejectSignature(signatureVerifyRequest)
                    }))
                    self?.showMessageWithOptions(message: "Accept Signature?", alertActions: alertActions, completion: nil)
                }
            }
        }
    }
    
    
    
    /*
     * Response to vault a card.
     */
    public func  onVaultCardResponse ( _ response:VaultCardResponse ) -> Void {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if response.success {
                if let vaultedCard = response.card,
                    let vaultedPOScard = POSCard(card: vaultedCard) {
                    self.store.addVaultedCard(vaultedPOScard)
                    self.showMessage("Card successfully vaulted")
                } else {
                    self.showMessage("Error with card data")
                }
                
            } else {
                self.showMessage("Error capturing card")
            }
        }
    }
    
    
    public func onDeviceActivityEnd(_ deviceEvent: CloverDeviceEvent) {
        DispatchQueue.main.async{ [weak self] in
            debugPrint("END -> " + (deviceEvent.eventState?.rawValue ?? "UNK") + ":" + (deviceEvent.message ?? ""))
            if let alertController = self?.viewController?.presentedViewController as? UIAlertController {
                if alertController.message == deviceEvent.message { // this check is because the events aren't guaranteed to be in order. could be START(A), START(B), END(A), END(B)
                    alertController.dismiss(animated: false, completion: nil)
                    self?.lastDeviceEvent = nil
                }
            } else {
                self?.lastDeviceEvent = nil
            }
        }
    }
    
    public func onDeviceActivityStart(_ deviceEvent: CloverDeviceEvent) {
        DispatchQueue.main.async{ [weak self] in
            debugPrint("START -> " + (deviceEvent.eventState?.rawValue ?? "UNK") + ":" + (deviceEvent.message ?? ""))
            self?.showMessageWithEvent(deviceEvent: deviceEvent)
        }
    }

    
    public func onDeviceError(_ deviceErrorEvent: CloverDeviceErrorEvent) {
        DispatchQueue.main.async{ [weak self] in
            guard let self = self else { return }
            
            if deviceErrorEvent.errorType == .CONNECTION_ERROR && self.suppressConnectionErrors == true {
                return //we've already handled this error since the last successful connection, don't spam the user
            }
            
            if deviceErrorEvent.errorType == .CONNECTION_ERROR {
                self.suppressConnectionErrors = true
            }

            
            self.showMessageWithOptions(
                title: deviceErrorEvent.errorType.rawValue,
                message: deviceErrorEvent.message,
                alertActions: [UIAlertAction(
                    title: "OK",
                    style: .cancel,
                    handler: nil)],
                completion: nil)
        }
    }

    public func onDeviceConnected() {
        ready = false // the device is connected, but not ready to communicate
        suppressConnectionErrors = false //we've reconnected, clear the flag so we show future connection errors
    }
    
    public func onDeviceDisconnected() {
        if ready {
            showMessage("Disconnected", duration: 2)
        }
        ready = false
    }
    
    public func onTipAdded(_ message: TipAddedMessage) {
        showMessage("Tip Added: " + (CurrencyUtils.IntToFormat(message.tipAmount ?? 0) ?? CurrencyUtils.FormatZero()), duration: 1)
    }
    
    public func onDeviceReady(_ merchantInfo: MerchantInfo) {
        if !ready { // only catch changes to ready, not other calls to onDeviceReady
            showMessage("Ready", duration: 0.1, afterDismiss:  {
                DispatchQueue.main.async { [weak self] in
                    guard let viewController = self?.viewController as? ViewController else { return }
                    viewController.performSegue(withIdentifier: "ShowTabs", sender: self)
                }
                
            })
            ready = true
        }
    }
    
    
    public func onConfirmPaymentRequest(_ request: ConfirmPaymentRequest) {
        if let payment = request.payment,
            let challenges = request.challenges {
            confirmPaymentRequest(payment: payment, challenges: challenges)
        } else {
            showMessage("No payment in request..")
        }
    }
    func confirmPaymentRequest(payment:CLVModels.Payments.Payment, challenges: [Challenge]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if challenges.count == 0 {
                print("accepting")
                self.cloverConnector?.acceptPayment(payment)
            } else {
                print("showing verify payment message")
                var challenges = challenges
                let challenge = challenges.removeFirst()
                var alertActions = [UIAlertAction]()
                alertActions.append(UIAlertAction(title: "Accept", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    self.confirmPaymentRequest(payment: payment, challenges: challenges)
                }))
                alertActions.append(UIAlertAction(title: "Reject", style: .cancel, handler: { [weak self] action in
                    guard let self = self else { return }
                    self.cloverConnector?.rejectPayment(payment, challenge: challenge)
                }))
                self.showMessageWithOptions(title: "Verify Payment", message: challenge.message ?? "", alertActions: alertActions)
            }
        }
    }
    
    public func onRefundPaymentResponse(_ refundPaymentResponse: RefundPaymentResponse) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if refundPaymentResponse.success {
                self.showMessage("Refund successful")
                for order in self.store.orders {
                    for p in order.payments {
                        if p.paymentId == refundPaymentResponse.paymentId {
                            guard let refundId = refundPaymentResponse.refund?.id,
                                let paymentId = refundPaymentResponse.paymentId,
                                let orderId = refundPaymentResponse.orderId,
                                let refundAmt = refundPaymentResponse.refund?.amount else { return }
                            p.status = .REFUNDED
                            let refund = POSRefund(refundId: refundId, paymentId: paymentId, orderID: orderId, employeeId: "DFLTEMPLE", amount: refundAmt)
                            self.store.addRefundToOrder(refund, order: order )
                        }
                    }
                }
            } else {
                if let failureMessage = refundPaymentResponse.message {
                    self.showMessage(failureMessage, duration: 5)
                } else {
                    self.showMessage("Refund failed.")
                }
            }
        }
    }
    
    public func onVoidPaymentRefundResponse(_ response: VoidPaymentRefundResponse) {
        showMessage("Payment refund " + response.refundId + " completed with " + response.result.rawValue + " status")
    }
    
    public func onPrintPaymentReceipt(_ printPaymentReceiptMessage: PrintPaymentReceiptMessage) {
        showMessage("Print Payment Receipt: " + formatCurrency(printPaymentReceiptMessage.payment?.amount))
    }
    
    public func onPrintRefundPaymentReceipt(_ printRefundPaymentReceiptMessage: PrintRefundPaymentReceiptMessage) {
        showMessage("Print Refund Payment Receipt: " + formatCurrency(printRefundPaymentReceiptMessage.refund?.amount) + " of " + formatCurrency(printRefundPaymentReceiptMessage.payment?.amount))
    }
    
    public func onPrintPaymentDeclineReceipt(_ printPaymentDeclineReceiptMessage: PrintPaymentDeclineReceiptMessage) {
        showMessage("Print Payment Declined Receipt: " + formatCurrency(printPaymentDeclineReceiptMessage.payment?.amount))
    }
    
    public func onPrintPaymentMerchantCopyReceipt(_ printPaymentMerchantCopyReceiptMessage: PrintPaymentMerchantCopyReceiptMessage) {
        showMessage("Print Payment Merchant Copy Receipt: " + formatCurrency(printPaymentMerchantCopyReceiptMessage.payment?.amount))
    }
    
    public func onPrintManualRefundReceipt(_ printManualRefundReceiptMessage: PrintManualRefundReceiptMessage) {
        showMessage("Print Manual Refund Receipt: " + formatCurrency(printManualRefundReceiptMessage.credit?.amount))
    }
    
    public func onPrintManualRefundDeclineReceipt(_ printManualRefundDeclineReceiptMessage: PrintManualRefundDeclineReceiptMessage) {
        showMessage("Print Manual Refund Decline Receipt: " + formatCurrency(printManualRefundDeclineReceiptMessage.credit?.amount))
    }
    
    public func onDisplayReceiptOptionsResponse(_ response: DisplayReceiptOptionsResponse) {
        showMessage("Display receipt options: \(String(describing: response.resultStatus?.rawValue))")
    }
    
    public func onRetrievePrintersResponse(_ retrievePrintersResponse: RetrievePrintersResponse) {
        guard retrievePrintersResponse.success == true else {
            showMessage("Error retrieving printers")
            self.getPrintersCallback?(retrievePrintersResponse)
            return
        }
        
        if let printers = retrievePrintersResponse.printers, let printerName = printers.first?.name {
            let message = "Retrieved printer: \(printerName) \(printers.count > 1 ? " and \(printers.count - 1) others" : "")"
            showMessage(message)
        }
        
        self.getPrintersCallback?(retrievePrintersResponse)
    }
    
    public func onPrintJobStatusResponse(_ printJobStatusResponse:PrintJobStatusResponse) {
        DispatchQueue.main.async {
            if let printRequestId = printJobStatusResponse.printRequestId, let callback = self.printJobStatusDict[printRequestId] { //check that we have a callback for this specific printRequestId
                callback(printJobStatusResponse)
                return //since user has provided their own callback to handle this, don't also continue below to fire the default behavior
            }
            
            if let jobId = printJobStatusResponse.printRequestId {
                let message = "Print job: " + jobId + "   status: " + printJobStatusResponse.status.rawValue
                self.showMessage(message)
            } else {
                self.showMessage("Print job status: " + printJobStatusResponse.status.rawValue)
            }
        }
    }
    
    fileprivate func formatCurrency(_ amount:Int?) -> String {
        return CurrencyUtils.IntToFormat(amount ?? 0) ?? CurrencyUtils.FormatZero()
    }

    public func onRetrievePendingPaymentsResponse(_ retrievePendingPaymentResponse: RetrievePendingPaymentsResponse) {
        if retrievePendingPaymentResponse.success {
            showMessage("Found " + String(retrievePendingPaymentResponse.pendingPayments?.count ?? -1) + " pending payment " + (retrievePendingPaymentResponse.pendingPayments?.count != 1 ? "s" : ""))
        } else {
            showMessage("Error getting pending payments")
        }
    }
    
    public func onReadCardDataResponse(_ readCardDataResponse: ReadCardDataResponse) {
        if readCardDataResponse.success {
            showMessage((readCardDataResponse.cardData?.first6 ?? "______") + "xxxxxx" + (readCardDataResponse.cardData?.last4 ?? "____"))
        } else {
            showMessage("Read Card Data Failed")
        }
        cloverConnector?.showWelcomeScreen()
    }
    
    public func onCustomActivityResponse(_ customActivityResponse: CustomActivityResponse) {
        if customActivityResponse.success {
            showMessage(customActivityResponse.payload ?? " Done")
        } else {
            showMessage("Custom activity canceled")
        }
    }
    
    public func onResetDeviceResponse(_ response: ResetDeviceResponse) {
        if response.success {
            showMessage("Device reset: " + response.state.rawValue)
        } else {
            showMessage("Device reset failed!")
        }
    }
    
    var onMessageFromActivityCallback:((_ response: MessageFromActivity)->())?
    public func onMessageFromActivity(_ response: MessageFromActivity) {
        onMessageFromActivityCallback?(response)
        showMessage("from " + (response.action) + ", got: " + (response.payload ?? "<nil payload>"))
    }
    
    public func onRetrievePaymentResponse(_ response: RetrievePaymentResponse) {
        switch response.queryStatus {
        case .FOUND:
            if let st = response.payment?.cardTransaction?.state {
                showMessage("payment found for: " + (response.externalPaymentId ?? "unk") + ". status: " + st.rawValue)
            } else {
                showMessage("payment found for: " + (response.externalPaymentId ?? "unk") + ". status: UNKNOWN")
            }
        case .NOT_FOUND:
            showMessage("payment not found for: " + (response.externalPaymentId ?? "unk"))
        case .IN_PROGRESS:
            showMessage("payment in process: " + (response.externalPaymentId ?? "unk"))
        }
    }
    
    public func onRetrieveDeviceStatusResponse(_ response: RetrieveDeviceStatusResponse) {
        if response.state != .WAITING_FOR_POS {
            showMessage("Device is currently: " + response.state.rawValue)
        } else {
            debugPrint("Device is currently: " + response.state.rawValue)
        }
    }
    
    public func onInvalidStateTransitionResponse(_ response: InvalidStateTransitionResponse) {
        let message = "Invalid transition from \(response.state?.rawValue ?? "previous state") to \(response.requestedTransition ?? "requested state")"
        debugPrint(message)
        debugPrint(response)
        showMessage(message)
    }
    
    public func onPairingCode(_ pairingCode:String) {
        DispatchQueue.main.async{ [weak self] in
            self?.showMessageWithOptions(message: "Enter code: \(pairingCode)")
        }
    }
    
    public func onPairingSuccess(_ pairingAuthToken:String) {
        DispatchQueue.main.async { [weak self] in
            guard let alertController = self?.viewController?.presentedViewController as? UIAlertController,
                let message = alertController.message else { return }
            if message.hasPrefix("Enter code: ") {
                alertController.dismiss(animated: false, completion: nil)
            }
        }
    }
    
    var customerProvidedDataCallback:((_ event:CustomerProvidedDataEvent)->())?
    public func onCustomerProvidedDataEvent(_ event: CustomerProvidedDataEvent) {
        customerProvidedDataCallback?(event)
        CCLog.d("Received Customer Provided Data Event")
        CCLog.d("\(event.data ?? "")")
    }
    
    
}


