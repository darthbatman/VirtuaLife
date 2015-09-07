//
//  ViewController.swift
//  HeartLifeNew
//
//  Created by Syed Mohideen on 9/6/15.
//  Copyright © 2015 VirtuaLife. All rights reserved.
//

import UIKit
import AVFoundation
import HealthKit
import Foundation
import CoreLocation
import WatchConnectivity

class ViewController: UIViewController, WCSessionDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    

    
    @IBOutlet weak var label: UILabel!
    var heartRate = [String]()
    var session: WCSession!
    
    let healthKitStore:HKHealthStore = HKHealthStore()
    
    let textLayer: CATextLayer = CATextLayer()
    let speedLayer: CATextLayer = CATextLayer()
    let stepsLayer: CATextLayer = CATextLayer()
    let timerLayer: CATextLayer = CATextLayer()
    let currentTimeLayer: CATextLayer = CATextLayer()
    
    let heightQuantity = HKQuantityType.quantityTypeForIdentifier(
        HKQuantityTypeIdentifierHeight)!
    
    let weightQuantity = HKQuantityType.quantityTypeForIdentifier(
        HKQuantityTypeIdentifierBodyMass)!
    
    let heartRateQuantity = HKQuantityType.quantityTypeForIdentifier(
        HKQuantityTypeIdentifierHeartRate)!
    
    let numOfSteps = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)!
    
    var totalSteps: Int = 0
    
    lazy var healthStore = HKHealthStore()
    
    /* The type of data that we wouldn't write into the health store */
    lazy var typesToShare: Set<HKSampleType> = {
        return [self.heightQuantity, self.weightQuantity]
        }()
    
    /* We want to read this type of data */
    lazy var typesToRead: Set<HKObjectType> = {
        return [self.heightQuantity, self.weightQuantity, self.heartRateQuantity, self.numOfSteps]
        
        }()

    func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        
        var receivedMSG = message["timer"] as! String
        let heartMSG = message["heartRate"] as! String
        
        print(String(receivedMSG))
        receivedMSG = String(receivedMSG)
        print("heart \(heartMSG)")
        
        
        
        if (receivedMSG == "Optional(\"start\")") {
            //start timer
            print("start")
            startTimer()
        } else if (receivedMSG == "Optional(\"stop\")") {
            //stop timer
            stopTimer()
        }

        
        //Use this to update the UI instantaneously (otherwise, takes a little while)
        dispatch_async(dispatch_get_main_queue()) {
            self.textLayer.string = heartMSG
            self.heartRate.append(heartMSG)
            self.label.text = heartMSG
        }
    }
    
    var theTimer: NSTimer = NSTimer()
    
    func startTimer() {
        theTimer = NSTimer()
        
        timerCount = 0
        timerLayer.foregroundColor = UIColor.greenColor().CGColor
        timerLayer.string = "0:00"
        
        theTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "updateTimer", userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        //timerCount = 0
        timerLayer.foregroundColor = UIColor(hue: 3, saturation: 3, brightness: 3, alpha: 0).CGColor
        timerLayer.string = "0:80"
        theTimer.invalidate()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        //previewLayer?.frame = self.view.bounds
        //previewLayer?.frame = cameraViewOne.layer.frame
        if HKHealthStore.isHealthDataAvailable(){
            
            healthStore.requestAuthorizationToShareTypes(typesToShare,
                readTypes: typesToRead,
                completion: {succeeded, error in
                    
                    if succeeded && error == nil{
                        print("Successfully received authorization")
                    } else {
                        if let theError = error{
                            print("Error occurred = \(theError)")
                        }
                    }
                    
            })
            
        } else {
            print("Health data is not available")
        }
    }
    
    var hour: Int = 0
    var minutes: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if (WCSession.isSupported()) {
            session = WCSession.defaultSession()
            session.delegate = self;
            session.activateSession()
        }
        
        startTimer()
        
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = 1;
        self.locationManager.startUpdatingLocation()
        
        
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(NSCalendarUnit([.Hour, .Minute]), fromDate: date)
        hour = components.hour
        minutes = components.minute
        
        //print("Time: \(hour) : \(minutes)")
        
        if (minutes < 10) {
            currentTimeLayer.string = "\(hour) : 0\(minutes)"
        } else {
            currentTimeLayer.string = "\(hour) : \(minutes)"
        }
        
        
        
        self.refreshHealthData()
        _ = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "refreshHealthData", userInfo: nil, repeats: true)
        _ = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "clockUpdate", userInfo: nil, repeats: true)
        
        
        
    }
    
    func clockUpdate() {
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(NSCalendarUnit([.Hour, .Minute]), fromDate: date)
        hour = components.hour
        minutes = components.minute
        
        //print("Time: \(hour) : \(minutes)")
        
        if (minutes < 10) {
           currentTimeLayer.string = "\(hour) : 0\(minutes)"
        } else {
             currentTimeLayer.string = "\(hour) : \(minutes)"
        }
       
    }
    
    var timerCount: Int = 0
    
    func updateTimer() {
        timerCount++
        var min = timerCount / 60
        var sec = timerCount % 60
        
        if (sec < 10) {
            timerLayer.string = "\(min) : 0\(sec)"
        } else {
            timerLayer.string = "\(min) : \(sec)"
        }
        
        
    }
    
    var oldSteps: Int = 0
    
    func refreshHealthData() {
        
        //print("refreshHealthData")
        
        //        let currentSpeed = locationManager.location?.speed
        //
        //        print(currentSpeed)
        //
        //        self.speedLayer.string = String(stringInterpolationSegment: currentSpeed)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate,
            ascending: false)
        
        let numOfStepsQuery = HKSampleQuery(sampleType: numOfSteps, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor], resultsHandler: {query, results, sample in
            guard let results = results where results.count > 0 else {
                //print("Could not read the user's bpm ")
                //print("or no bpm data was available")
                return
            }
            
            /* We only have one sample really */
            let sample = results[0] as! HKQuantitySample
            let numOfStepsCount = sample.quantity.doubleValueForUnit(HKUnit.countUnit())
            
            if (self.oldSteps == Int(numOfStepsCount)) {
                
            } else {
                self.totalSteps += Int(numOfStepsCount)
                self.oldSteps = Int(numOfStepsCount)
            }
            
            
            
            dispatch_async(dispatch_get_main_queue(), {
                
                /* Set the value of "KG" on the right hand side of the
                text field */
                self.stepsLayer.string = "\(self.totalSteps) Steps"
                
                /* And finally set the text field's value to the user's
                weight */
                
            })
        })
        
        healthStore.executeQuery(numOfStepsQuery)
        
//        let heartRateQuery = HKSampleQuery(sampleType: heartRateQuantity,
//            predicate: nil,
//            limit: 1,
//            sortDescriptors: [sortDescriptor],
//            resultsHandler: {query, results, sample in
//                
//                guard let results = results where results.count > 0 else {
//                    print("Could not read the user's bpm ")
//                    print("or no bpm data was available")
//                    return
//                }
//                
//                /* We only have one sample really */
//                let sample = results[0] as! HKQuantitySample
//                /* Get the weight in kilograms from the quantity */
//                let heartRateInBPM = sample.quantity.doubleValueForUnit(HKUnit.countUnit().unitDividedByUnit(HKUnit.minuteUnit()))
//                
//                /* This is the value of "KG", localized in user's language */
//                
//                dispatch_async(dispatch_get_main_queue(), {
//                    
//                    /* Set the value of "KG" on the right hand side of the
//                    text field */
//                    self.textLayer.string = String(stringInterpolationSegment: heartRateInBPM)
//                    
//                    /* And finally set the text field's value to the user's
//                    weight */
//                    
//                })
//                
//        })
//        
//        healthStore.executeQuery(heartRateQuery)
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
        print(newLocation)
        
        var distance: CLLocationDistance = newLocation.distanceFromLocation(oldLocation)
        var timeDiff: NSTimeInterval = newLocation.timestamp.timeIntervalSinceDate(oldLocation.timestamp)
        
        var realSpeed = (distance / timeDiff) * 2.23693629
        realSpeed = floor(realSpeed)
        
        let gpsSpeed: Double = newLocation.speed
        print(realSpeed)
        self.speedLayer.string = "Speed: \(realSpeed) mph"
    }
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        
        let backCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        let input = try! AVCaptureDeviceInput(device: backCamera)
        
        //var input = AVCaptureDeviceInput(device: backCamera, error: &error)
        var output: AVCaptureVideoDataOutput?
        
        if captureSession?.canAddInput(input) != nil {
            captureSession?.addInput(input)
            
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            
            output = AVCaptureVideoDataOutput()
            
            if (captureSession?.canAddOutput(output) != nil) {
                
                //captureSession?.addOutput(stillImageOutput)
                captureSession?.addOutput(output)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                previewLayer?.frame = CGRect(x: 48, y: 60, width: 296, height: 280)
                //previewLayer?.frame = CGRect(self.view.bounds)
                
                let replicatorLayer = CAReplicatorLayer()
                //replicatorLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width / 2, self.view.bounds.size.height)
                replicatorLayer.frame = CGRectMake(4, 4, 300, 240)
                replicatorLayer.instanceCount = 2
                //replicatorLayer.instanceTransform = CATransform3DMakeTranslation(self.view.bounds.size.width / 2, 0.0, 0.0)
                replicatorLayer.instanceTransform = CATransform3DMakeTranslation(300, 0.0, 0.0)
                //replicatorLayer.instanceTransform = CATransform3DMakeTranslation(0.0, self.view.bounds.size.height / 2, 0.0)
                
                previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
                
                let smallHeart: UIImage = UIImage(named: "heartSmall.png")!
                let flippedHeart: UIImageView = UIImageView(image: UIImage(CGImage: smallHeart.CGImage!, scale: smallHeart.scale, orientation: UIImageOrientation.Up))
                
                flippedHeart.frame = CGRectMake(188, 190, 24, 22)
                
                previewLayer?.addSublayer(flippedHeart.layer)
                
                textLayer.font = "Helvetica"
                textLayer.fontSize = 10
                textLayer.frame = CGRectMake(188, 190, 24, 22)
                textLayer.alignmentMode = kCAAlignmentCenter
                textLayer.string = "0"
                textLayer.foregroundColor = UIColor.whiteColor().CGColor
                //textLayer.backgroundColor = UIColor(patternImage: flippedHeart).CGColor
                //textLayer.backgroundColor = UIColor.blueColor().CGColor
                //textLayer.cornerRadius = 10
                
                speedLayer.font = "Helvetica"
                speedLayer.fontSize = 10
                speedLayer.frame = CGRectMake(70, 184, 144, 24)
                speedLayer.alignmentMode = kCAAlignmentLeft
                speedLayer.string = "Speed: 0 mph"
                speedLayer.foregroundColor = UIColor.greenColor().CGColor
                //background image?
                
                
                stepsLayer.font = "Helvetica"
                stepsLayer.fontSize = 16
                stepsLayer.frame = CGRectMake(24, 120, 100, 100)
                stepsLayer.alignmentMode = kCAAlignmentLeft
                stepsLayer.string = "0 Steps"
                stepsLayer.foregroundColor = UIColor.greenColor().CGColor
                
                timerLayer.font = "Helvetica"
                timerLayer.fontSize = 16
                timerLayer.frame = CGRectMake(180, 120, 100, 100)
                timerLayer.alignmentMode = kCAAlignmentCenter
                timerLayer.string = "0"
                timerLayer.foregroundColor = UIColor.greenColor().CGColor
                
                currentTimeLayer.font = "Helvetica"
                currentTimeLayer.fontSize = 10
                currentTimeLayer.frame = CGRectMake(150, 60, 48, 32)
                currentTimeLayer.alignmentMode = kCAAlignmentCenter
                currentTimeLayer.string = "0"
                currentTimeLayer.foregroundColor = UIColor.greenColor().CGColor
                
                
                var imageView: UIImageView = UIImageView(image: UIImage(named: "smallHUD.png"))
                imageView.frame = CGRect(x: 0, y: 50, width: 320, height: 180)
                
                var speedView: UIImageView = UIImageView(image: UIImage(named: "smallSpeed.png"))
                speedView.frame = CGRectMake(35, 182, 32, 32)
                
                previewLayer?.addSublayer(speedView.layer)
                
                previewLayer?.addSublayer(imageView.layer)
                
                previewLayer?.addSublayer(currentTimeLayer)
                previewLayer?.addSublayer(timerLayer)
                previewLayer?.addSublayer(stepsLayer)
                previewLayer?.addSublayer(speedLayer)
                previewLayer?.addSublayer(textLayer)
                
                //previewLayer?.addSublayer(button.layer)
                replicatorLayer.addSublayer(previewLayer!)
                
                //previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
                //                self.cameraViewOne.layer.addSublayer(previewLayer!)
                //                self.cameraViewTwo.layer.addSublayer(previewLayer!)
                self.view.layer.addSublayer(replicatorLayer)
                captureSession?.startRunning()
            }
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    




}

