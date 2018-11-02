//
//  LoyaltyTestViewController.swift
//  CloverConnector iOS Example
//
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import CloverConnector
import ObjectMapper

fileprivate enum LoyaltyExtrasTypes:String {
    case POINTS
    case OFFERS
}
extension CLVModels.Loyalty.LoyaltyDataTypes {
    public static let ACCOUNT_TYPE:String = "com.loyalty.AccountNumber"
    public static let BARCODE_TYPE:String = "BARCODE"
}

class LoyaltyTestViewController: UIViewController {
    @IBOutlet var closeButton: UIButton!
    @IBOutlet weak var textView:UITextView!
    @IBOutlet weak var accountNumberSwitch: UISwitch!
    @IBOutlet weak var barCodeSwitch: UISwitch!
    @IBOutlet weak var phoneNumberSwitch: UISwitch!
    @IBOutlet weak var VASSwitch: UISwitch!
    @IBOutlet weak var customActivityTextField: UITextField!
    
    
    var activityName:String = UserDefaults.standard.string(forKey: "activityName") ?? "com.clover.remote_clover_loyalty.CloverLoyaltyCustomActivity" {
        didSet {
            UserDefaults.standard.set(activityName, forKey: "activityName")
            UserDefaults.standard.synchronize()
        }
    }
    var providerPackage:String = UserDefaults.standard.string(forKey: "providerPackage") ?? "com.clover.loyalty.CLE" {
        didSet {
            UserDefaults.standard.set(providerPackage, forKey: "providerPackage")
            UserDefaults.standard.synchronize()
        }
    }
    var pushURL:String = UserDefaults.standard.string(forKey: "pushURL") ?? "st.clover.com" {
        didSet {
            UserDefaults.standard.set(pushURL, forKey: "pushURL")
            UserDefaults.standard.synchronize()
        }
    }
    var pushTitle:String = UserDefaults.standard.string(forKey: "pushTitle") ?? "Test ST Push Url" {
        didSet {
            UserDefaults.standard.set(pushTitle, forKey: "pushTitle")
            UserDefaults.standard.synchronize()
        }
    }

    var appDelegate: AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        customActivityTextField.text = activityName

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
    }
    func printToScreen(string:String) {
        let text = textView?.text ?? ""
        textView.text = "\(text)\(text.count > 0 ? "\n\n" : "")\(string)"
        
        if textView.text.count > 0 {
            let location = textView.text.count - 1
            let bottom = NSMakeRange(location, 1)
            textView.scrollRangeToVisible(bottom)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate?.cloverConnectorListener?.onMessageFromActivityCallback = { message in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.printToScreen(string: "\(message.action)\n\(message.payload ?? "nil payload")")
            }
            
        }
        appDelegate?.cloverConnectorListener?.customerProvidedDataCallback = { customerProvidedDataEvent in
            DispatchQueue.main.async { [weak self] in
                var outputText = "eventId: \(customerProvidedDataEvent.eventId ?? "")\n"
                outputText +=    "config:  \(customerProvidedDataEvent.config?.type ?? "")\n"
                if let config = customerProvidedDataEvent.config?.configuration {
                    for thisConfig in config {
                        outputText +=    "         \(thisConfig.key): \(thisConfig.value)"
                    }
                }
                outputText +=    "data:    \(customerProvidedDataEvent.data ?? "")"
                self?.printToScreen(string: outputText)
                
                if let type = customerProvidedDataEvent.config?.type {
                    switch type {
                    case CLVModels.Loyalty.LoyaltyDataTypes.CLEAR_TYPE:
                        if let strongSelf = self {
                            strongSelf.clearCustomerButtonTapped(strongSelf)
                        }
                    case CLVModels.Loyalty.LoyaltyDataTypes.PHONE_TYPE:
                        if let data = customerProvidedDataEvent.data {
                            
                            let customerInfo = CLVModels.Customers.CustomerInfo()
                            
                            let phoneNumber = CLVModels.Customers.PhoneNumber()
                            phoneNumber.phoneNumber = data
                            
                            switch data {
                            case "8675309":
                                customerInfo.customer = CLVModels.Customers.Customer(firstName:"Jenny", phoneNumbers: [phoneNumber])
                                customerInfo.externalId = UUID().uuidString
                                customerInfo.displayString = "Welcome back Jenny!"
                            case "6345789":
                                customerInfo.customer = CLVModels.Customers.Customer(firstName:"Wilson", lastName:"Pickett", phoneNumbers: [phoneNumber])
                                customerInfo.externalId = UUID().uuidString
                                customerInfo.displayString = "Welcome back Wicked Pickett!"
                            default:
                                self?.setCustomerInfoN00B()
                                return
                            }

                            var extras = [LoyaltyExtrasTypes.POINTS.rawValue:"100"]
                            if let offerJSON = Mapper().toJSONString([CLVModels.Loyalty.Offer(id: "01", label: "5% Off"),CLVModels.Loyalty.Offer(id: "03", label: "BOGO Frisbees")]) {
                                extras[LoyaltyExtrasTypes.OFFERS.rawValue] = offerJSON
                            }
                            customerInfo.extras = extras
                            
                            self?.appDelegate?.cloverConnector?.setCustomerInfo(SetCustomerInfoRequest(customerInfo: customerInfo))
                        } else {
                            self?.setCustomerInfoN00B()
                        }
                    case CLVModels.Loyalty.LoyaltyDataTypes.ACCOUNT_TYPE:
                        if let data = customerProvidedDataEvent.data {
                            
                            let customerInfo = CLVModels.Customers.CustomerInfo()

                            switch data {
                            case "411":
                                customerInfo.customer = CLVModels.Customers.Customer(firstName:"Operator")
                                customerInfo.externalId = UUID().uuidString
                                customerInfo.displayString = "Welcome back Operator"

                            case "42":
                                customerInfo.customer = CLVModels.Customers.Customer(firstName:"Douglas",lastName:"Adams")
                                customerInfo.externalId = UUID().uuidString
                                customerInfo.displayString = "Welcome back Mr. Adams"
                            default:
                                self?.setCustomerInfoN00B()
                                return
                            }

                            customerInfo.externalId = data
                            
                            var extras = [LoyaltyExtrasTypes.POINTS.rawValue:"100"]
                            if let offerJSON = Mapper().toJSONString([CLVModels.Loyalty.Offer(id: "01", label: "50% Off")]) {
                                extras[LoyaltyExtrasTypes.OFFERS.rawValue] = offerJSON
                            }
                            customerInfo.extras = extras
                            
                            
                            self?.appDelegate?.cloverConnector?.setCustomerInfo(SetCustomerInfoRequest(customerInfo: customerInfo))
                        } else {
                            self?.setCustomerInfoN00B()
                        }
                    default: break
                    }
                }
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appDelegate?.cloverConnectorListener?.customerProvidedDataCallback = nil
        appDelegate?.cloverConnectorListener?.onMessageFromActivityCallback = nil
    }
    
    func setCustomerInfoN00B() {
        let customerInfo = CLVModels.Customers.CustomerInfo()
        customerInfo.externalId = UUID().uuidString
        customerInfo.displayString = "Welcome n00b!"
        customerInfo.customer = CLVModels.Customers.Customer(firstName:"n00b")
        
        var extras = [LoyaltyExtrasTypes.POINTS.rawValue:"0"]
        if let offerJSON = Mapper().toJSONString([CLVModels.Loyalty.Offer(id: "01", label: "5% Off"),CLVModels.Loyalty.Offer(id: "02", label: "Free Ketchup!")]) {
            extras[LoyaltyExtrasTypes.OFFERS.rawValue] = offerJSON
        }
        customerInfo.extras = extras
        
        self.appDelegate?.cloverConnector?.setCustomerInfo(SetCustomerInfoRequest(customerInfo: customerInfo))
    }
    



    @IBAction func vasConfigTapped(_ sender: Any) {
        let alert = UIAlertController(title: "VAS Configuration", message: "You can request VAS data from sources like Apple Pass and Google SmartTap.  \n\nConfigure the fields below to request this data.  By default, this example can request data configured using the example data provider.\n\nAfter changing this field, be sure and update your registration using the Register button.", preferredStyle: .alert)
        alert.addTextField(configurationHandler: { [weak self] textField in
            textField.text = self?.providerPackage
            textField.placeholder = "Provider Package"
        })
        alert.addTextField(configurationHandler: { [weak self] textField in
            textField.text = self?.pushURL
            textField.placeholder = "Push URL"
        })
        alert.addTextField(configurationHandler: { [weak self] textField in
            textField.text = self?.pushTitle
            textField.placeholder = "Push Title"
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
            guard let textFields = alert.textFields,
                textFields.count >= 3 else { return }
            guard let package = textFields[0].text else { return }
            guard let pushURL = textFields[1].text else { return }
            guard let pushTitle = textFields[2].text else { return }
            self?.providerPackage = package
            self?.pushURL = pushURL
            self?.pushTitle = pushTitle
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    @IBAction func registerButtonTapped(_ sender: UIButton) {
        var configurations = [DataProviderConfig]()
        if accountNumberSwitch.isOn {
            configurations.append(DataProviderConfig(type: CLVModels.Loyalty.LoyaltyDataTypes.ACCOUNT_TYPE))
        }
        if barCodeSwitch.isOn {
            configurations.append(DataProviderConfig(type: CLVModels.Loyalty.LoyaltyDataTypes.BARCODE_TYPE))
        }
        if phoneNumberSwitch.isOn {
            configurations.append(DataProviderConfig(type: CLVModels.Loyalty.LoyaltyDataTypes.PHONE_TYPE))
        }
        if VASSwitch.isOn, let supportedServices = CLVModels.Loyalty.VasDataTypeType.allCasesJson {
            var vasConfigurations = [String:String]()
            vasConfigurations[CLVModels.Loyalty.LoyaltyDataTypes.VAS_TYPE_KEYS.PROVIDER_PACKAGE] = providerPackage
            vasConfigurations[CLVModels.Loyalty.LoyaltyDataTypes.VAS_TYPE_KEYS.PROTOCOL_ID] = CLVModels.Loyalty.VasProtocol.ST.rawValue
            vasConfigurations[CLVModels.Loyalty.LoyaltyDataTypes.VAS_TYPE_KEYS.SUPPORTED_SERVICES] = supportedServices
            vasConfigurations[CLVModels.Loyalty.LoyaltyDataTypes.VAS_TYPE_KEYS.PUSH_URL] = pushURL
            vasConfigurations[CLVModels.Loyalty.LoyaltyDataTypes.VAS_TYPE_KEYS.PUSH_TITLE] = pushTitle
            configurations.append(DataProviderConfig(type: CLVModels.Loyalty.LoyaltyDataTypes.VAS_TYPE, configuration: vasConfigurations))
        }
        configurations.append(DataProviderConfig(type: CLVModels.Loyalty.LoyaltyDataTypes.CLEAR_TYPE))
        appDelegate?.cloverConnector?.registerForCustomerProvidedData(RegisterForCustomerProvidedDataRequest(configurations:configurations))
    }
    
    @IBAction func startCustomActivity(_ sender: AnyObject) {
        guard let newActivityName = customActivityTextField.text else { return }
        activityName = newActivityName
        
        let car = CustomActivityRequest(activityName, payload: "")
        car.nonBlocking = true
        appDelegate?.cloverConnector?.startCustomActivity(car)
    }
    @IBAction func closeButtonTapped(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func clearCustomerButtonTapped(_ sender: AnyObject) {
        
        appDelegate?.cloverConnector?.setCustomerInfo(SetCustomerInfoRequest())
    }
    @IBAction func updateOrderButtonTapped(_ sender: Any) {
        guard let activityName = customActivityTextField.text else { return }

        let displayOrder = DisplayOrder()
        let dli1 = DisplayLineItem(id: "01", name: "Cheeseburger", price: "$7.99", quantity: "1")
        let dli2 = DisplayLineItem(id: "02", name: "French Fries (Large)", price: "$2.19", quantity: "1")
        displayOrder.lineItems = [dli1,dli2]
        displayOrder.total = "$10.18"
        guard let jsonDisplayOrder = Mapper().toJSONString(DisplayOrderObject(displayOrder: displayOrder)) else { return }

        let message = MessageToActivity(action: activityName, payload: jsonDisplayOrder)
        appDelegate?.cloverConnector?.sendMessageToActivity(message)
    }
    
    
    
    
    
    @IBAction func sendCustDataTapped(_ sender: Any) {
        appDelegate?.cloverConnector?.sendMessageToActivity(MessageToActivity(action: activityName, payload: "{\"command\":\"SendCustomerProvidedData\", \"config\": {\"type\":\"PHONE\"}, \"data\":\"8675309\"}"))
    }
    @IBAction func sendRegConfigsTapped(_ sender: Any) {
        appDelegate?.cloverConnector?.sendMessageToActivity(MessageToActivity(action: activityName, payload: "{\"command\":\"SendRegistrationConfigs\"}"))
    }
    @IBAction func sendCustInfoTapped(_ sender: Any) {
                appDelegate?.cloverConnector?.sendMessageToActivity(MessageToActivity(action: activityName, payload: "{\"command\":\"SendCustomerInfo\"}"))
    }
}




// This object exists to wrap a DisplayOrder into a key/value pair when serialized using ObjectMapper.  This isn't needed for the SDK, but the MessageToActivity required by the Loyalty examples do require it that way... so we'll put it into the example app for lack of any better place to put it.
class DisplayOrderObject: Mappable {
    var displayOrder:DisplayOrder?
    
    // This let exists in the SDK as internal.  Rather than mark it as public for the sake of example code that may or may not ever ship, I've duplicated it here.
    // If/when we ship this example code, we can revisit marking it as public in the SDK vs. leaving a copy of it here.
    let displayOrderTransform = TransformOf<DisplayOrder, String>(fromJSON: { (value: String?) -> DisplayOrder? in
        if let val = value {
            if let pi = Mapper<DisplayOrder>().map(JSONString: val) {
                return pi
            }
        }
        return nil
    }, toJSON: { (value: DisplayOrder?) -> String? in
        if let value = value,
            let valueJSON = Mapper().toJSONString(value, prettyPrint: false) {
            return String(valueJSON)
        }
        return nil
    })
    
    init(displayOrder:DisplayOrder) {
        self.displayOrder = displayOrder
    }

    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        displayOrder <- (map["displayOrder"], displayOrderTransform)
    }
    
    
}


