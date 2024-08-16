import CoreLocation
import React

@objc(Geofencing)
class Geofencing: RCTEventEmitter, CLLocationManagerDelegate {
    
    private var locationManager: CLLocationManager
    private var hasListeners = false
    private var allowWhileUsing = false
    private var allowAlways = false
    private var authorizationSuccessCallback: RCTResponseSenderBlock?
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc(getLocationAuthorizationStatus:withReject:)
    func getLocationAuthorizationStatus(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        resolve(getLocationAuthorizationStatus())
    }
    
    @objc(requestLocation: withSuccessCallback:)
    func requestLocation(params: NSDictionary, successCallback: @escaping RCTResponseSenderBlock) {
        
        guard let allowWhileUsing = params["allowWhileUsing"] as? Bool,
              let allowAlways = params["allowAlways"] as? Bool else {
            return
        }
        
        self.allowWhileUsing = allowWhileUsing
        self.allowAlways = allowAlways
        authorizationSuccessCallback = successCallback
        if allowAlways && CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    @objc(getRegisteredGeofences:withReject:)
    func getRegisteredGeofences(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if !isLocationAuthorized() {
            reject("Permission", "Needed Authorization always but got \(getLocationAuthorizationStatus())", NSError(domain: "getRegisteredGeofences", code: 200))
            return
        }
        
        let regions = locationManager.monitoredRegions
        let geofences: [String] = regions.map { region in region.identifier }
        resolve(geofences)
    }
    
    
    @objc(addGeofence:withResolve:withReject:)
    func addGeofence(params: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if !isLocationAuthorized() {
            reject("Permission", "Needed Authorization always but got \(getLocationAuthorizationStatus())", NSError(domain: "addGeofence", code: 200))
            return
        }
        
        guard let id = params["id"] as? String,
              let latitude = params["latitude"] as? Double,
              let longitude = params["longitude"] as? Double,
              let radius = params["radius"] as? Double else {
            reject("Invalid", "Invalid input", NSError(domain: "addGeofence", code: 200))
            return
        }
        
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: id)
        locationManager.startMonitoring(for: region)
        resolve(["success": true, "id": id])
    }
    
    @objc(removeGeofence:withResolve:withReject:)
    func removeGeofence(id: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if removeGeofence(id) {
            resolve(["success": true, "id": id])
        } else {
            resolve(["success": false, "error": "Geofence is not registered with the provided id"])
        }
    }
    
    @objc(removeAllGeofence:withReject:)
    func removeAllGeofence(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            try removeAll()
            resolve(["success": true])
        } catch let error {
            resolve(["success": false, "error": error.localizedDescription])
        }
    }
    
    private func removeAll() throws {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    private func removeGeofence(_ id: String) -> Bool {
        for region in locationManager.monitoredRegions {
            if region.identifier == id {
                locationManager.stopMonitoring(for: region)
                return true
            }
        }
        return false
    }
    
    override func supportedEvents() -> [String]! {
        return ["onEnter", "onExit"]
    }
    
    override func startObserving() {
        hasListeners = true
    }
    
    override func stopObserving() {
        hasListeners = false
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if hasListeners {
            sendEvent(withName: "onEnter", body: [region.identifier])
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                // wait for the react native to add listener
                self.sendEvent(withName: "onEnter", body: [region.identifier])
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if hasListeners {
            sendEvent(withName: "onExit", body: [region.identifier])
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                // wait for the react native to add listener
                self.sendEvent(withName: "onExit", body: [region.identifier])
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            authorizationSuccessCallback?([["success": true, "location": getLocationAuthorizationStatus()]])
        } else if status == .authorizedWhenInUse {
            if self.allowAlways  {
                locationManager.requestAlwaysAuthorization()
            } else {
                authorizationSuccessCallback?([["success": true, "location": getLocationAuthorizationStatus()]])
            }
        } else {
            authorizationSuccessCallback?([["success": false, "location": getLocationAuthorizationStatus()]])
        }
        
        authorizationSuccessCallback = nil
    }
    
    private func isLocationAuthorized() -> Bool {
        return CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways
    }
    
    private func getLocationAuthorizationStatus() -> String {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        var message: String
        
        switch authorizationStatus {
        case .authorizedAlways:
            message = "Always"
        case .authorizedWhenInUse:
            message = "WhenInUse"
        case .notDetermined:
            message = "NotDetermined"
        case .restricted:
            message = "Restricted"
        case .denied:
            message = "Denied"
        default:
            message = "Unknown"
        }
        
        return message
    }
    
}

