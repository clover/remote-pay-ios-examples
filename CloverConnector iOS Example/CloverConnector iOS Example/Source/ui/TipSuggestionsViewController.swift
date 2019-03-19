//  
//  TipSuggestionsViewController.swift
//  CloverConnector iOS Example
//
//  Copyright © 2019 Clover Network. All rights reserved.
//

import UIKit
import Foundation
import CloverConnector

class TipSuggestionsViewController: UIViewController {
    public let tipSuggestionsSegue = "tipSuggestionsSegue"
    private weak var store = POSStore.shared
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet var centeredConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var ts1Switch: UISwitch!
    @IBOutlet weak var ts2Switch: UISwitch!
    @IBOutlet weak var ts3Switch: UISwitch!
    @IBOutlet weak var ts4Switch: UISwitch!
    
    @IBOutlet weak var ts1Percentage: UITextField!
    @IBOutlet weak var ts2Percentage: UITextField!
    @IBOutlet weak var ts3Percentage: UITextField!
    @IBOutlet weak var ts4Percentage: UITextField!
    
    @IBOutlet weak var ts1Description: UITextField!
    @IBOutlet weak var ts2Description: UITextField!
    @IBOutlet weak var ts3Description: UITextField!
    @IBOutlet weak var ts4Description: UITextField!
    
    @IBOutlet weak var saveButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //register for keyboard notifications so we can move the modal out of the way
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(notification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)), name: UIResponder.keyboardDidHideNotification, object: nil)
        
        self.ts1Percentage.delegate = self
        self.ts1Description.delegate = self
        self.ts2Percentage.delegate = self
        self.ts2Description.delegate = self
        self.ts3Percentage.delegate = self
        self.ts3Description.delegate = self
        self.ts4Percentage.delegate = self
        self.ts4Description.delegate = self
        
        //custom styling for the view
        containerView.layer.cornerRadius = 4.0
        saveButton.layer.cornerRadius = 4.0

        //populate the UI with existing settings
        if let tipSuggestions = store?.transactionSettings.tipSuggestions {
            for (index, ts) in tipSuggestions.enumerated() {
                switch index {
                case 0:
                    ts1Switch.isEnabled = ts.isEnabled ?? false
                    ts1Percentage.text = String(optionalInt: ts.percentage)
                    ts1Description.text = ts.name
                case 1:
                    ts2Switch.isEnabled = ts.isEnabled ?? false
                    ts2Percentage.text = String(optionalInt: ts.percentage)
                    ts2Description.text = ts.name
                case 2:
                    ts3Switch.isEnabled = ts.isEnabled ?? false
                    ts3Percentage.text = String(optionalInt: ts.percentage)
                    ts3Description.text = ts.name
                case 3:
                    ts4Switch.isEnabled = ts.isEnabled ?? false
                    ts4Percentage.text = String(optionalInt: ts.percentage)
                    ts4Description.text = ts.name
                default:
                    CCLog.d("Unsupported number of tips")
                }
            }
        }
    }
    
    /// When the save button is tapped
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        var tipSuggestions = [CLVModels.Merchant.TipSuggestion]()
        
        //save all of the tip suggestions
        if let tipPercentageString = ts1Percentage.text, let tipPercentageInt = Int(tipPercentageString) { //key off of whether or not the percentage is provided, otherwise we don't care
            let tipSuggestion1 = CLVModels.Merchant.TipSuggestion()
            tipSuggestion1.isEnabled = ts1Switch.isEnabled
            tipSuggestion1.percentage = tipPercentageInt
            tipSuggestion1.name = ts1Description.text
            tipSuggestions.append(tipSuggestion1)
        }
        
        if let tipPercentageString = ts2Percentage.text, let tipPercentageInt = Int(tipPercentageString) { //key off of whether or not the percentage is provided, otherwise we don't care
            let tipSuggestion = CLVModels.Merchant.TipSuggestion()
            tipSuggestion.isEnabled = ts2Switch.isEnabled
            tipSuggestion.percentage = tipPercentageInt
            tipSuggestion.name = ts2Description.text
            tipSuggestions.append(tipSuggestion)
        }
        
        if let tipPercentageString = ts3Percentage.text, let tipPercentageInt = Int(tipPercentageString) { //key off of whether or not the percentage is provided, otherwise we don't care
            let tipSuggestion = CLVModels.Merchant.TipSuggestion()
            tipSuggestion.isEnabled = ts3Switch.isEnabled
            tipSuggestion.percentage = tipPercentageInt
            tipSuggestion.name = ts3Description.text
            tipSuggestions.append(tipSuggestion)
        }
        
        if let tipPercentageString = ts4Percentage.text, let tipPercentageInt = Int(tipPercentageString) { //key off of whether or not the percentage is provided, otherwise we don't care
            let tipSuggestion = CLVModels.Merchant.TipSuggestion()
            tipSuggestion.isEnabled = ts4Switch.isEnabled
            tipSuggestion.percentage = tipPercentageInt
            tipSuggestion.name = ts4Description.text
            tipSuggestions.append(tipSuggestion)
        }
        
        if tipSuggestions.count > 0 {
            store?.transactionSettings.tipSuggestions = tipSuggestions
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    /// When the blur view is tapped
    @IBAction func blurViewTapped(_ sender: UIView) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension TipSuggestionsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case ts1Percentage:
            ts1Description.becomeFirstResponder()
        case ts1Description:
            ts2Percentage.becomeFirstResponder()
        case ts2Percentage:
            ts2Description.becomeFirstResponder()
        case ts2Description:
            ts3Percentage.becomeFirstResponder()
        case ts3Percentage:
            ts3Description.becomeFirstResponder()
        case ts3Description:
            ts4Percentage.becomeFirstResponder()
        case ts4Percentage:
            ts4Description.becomeFirstResponder()
        case ts4Description:
            self.saveButtonTapped(UIButton())
        default:
            CCLog.d("unsupported textfield: was a new one added?")
        }
        
        return true
    }
}

//keyboard notifications handler
extension TipSuggestionsViewController {
    @objc func keyboardWasShown(notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.centeredConstraint.isActive = false
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillBeHidden(notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.centeredConstraint.isActive = true
            self.view.layoutIfNeeded()
        }
    }
}

extension String {
    init?(optionalInt: Int?) {
        guard let validInteger = optionalInt else { return nil }
        
        self.init(validInteger)
    }
}
