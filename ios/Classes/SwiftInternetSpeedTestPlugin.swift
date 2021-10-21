import Flutter
import UIKit



public class SwiftInternetSpeedTestPlugin: NSObject, FlutterPlugin {
    
    var callbackById: [Int: () -> ()] = [:]
    
    let speedTest = SpeedTest()
    static var channel: FlutterMethodChannel!
    
    public static func register(with registrar: FlutterPluginRegistrar) {
         channel = FlutterMethodChannel(name: "internet_speed_test", binaryMessenger: registrar.messenger())
        
        let instance = SwiftInternetSpeedTestPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    private func mapToCall(result: FlutterResult, arguments: Any?) {
        let argsMap = arguments as! [String: Any]
        let args = argsMap["id"] as! Int
        let authToken = (argsMap["args"] as? [String: Any])?["auth_token"] as? String
        var fileSize = 200
        if let fileSizeArgument = argsMap["fileSize"] as? Int {
            fileSize = fileSizeArgument
        }
        print("file is of size \(fileSize) Bytes")
        switch args {
        case 0:
            startListening(args: args, flutterResult: result, methodName: "startDownloadTesting", testServer: argsMap["testServer"] as! String, fileSize: fileSize)
            break
        case 1:
            startListening(args: args, flutterResult: result,
                           methodName: "startUploadTesting",
                           testServer: argsMap["testServer"] as! String,
                           fileSize: fileSize, authToken: authToken)
            break
        case 2:
            self.speedTest.stopDownloadTest()
        default:
            break
        }
    }
    
    func startListening(args: Any, flutterResult: FlutterResult, methodName:String, testServer: String, fileSize: Int, authToken: String? = nil) {
        print("Method name is \(methodName)")
        let currentListenerId = args as! Int
        print("id is \(currentListenerId)")

        let fun = {
            if (self.callbackById.contains(where: { (key, _) -> Bool in
                print("does contain key \(key == currentListenerId)")
                return key == currentListenerId
            })) {
                print("inside if")
                switch methodName {
                case "startDownloadTesting" :
                    self.speedTest.runDownloadTest(for: URL(string: testServer)!, size: fileSize, timeout: 20000, current: { (currentSpeed) in
                                var argsMap: [String: Any] = [:]
                                argsMap["id"] = currentListenerId
                                argsMap["transferRate"] = self.getSpeedInBytes(speed: currentSpeed)
                                argsMap["percent"] = 50
                                argsMap["type"] = 2
                                DispatchQueue.main.async {
                                    SwiftInternetSpeedTestPlugin.channel.invokeMethod("callListener", arguments: argsMap)
                                }
                            }, final: { (resultSpeed) in
                                switch resultSpeed {
                                case .value(let finalSpeed):
                                    var argsMap: [String: Any] = [:]
                                    argsMap["id"] = currentListenerId
                                    argsMap["transferRate"] = self.getSpeedInBytes(speed: finalSpeed)
                                    argsMap["percent"] = 100
                                    argsMap["type"] = 0
                                    DispatchQueue.main.async {
                                        SwiftInternetSpeedTestPlugin.channel.invokeMethod("callListener", arguments: argsMap)
                                    }
                                case .error(let error):
                                    print("Error is \(error.localizedDescription)")
                                    var argsMap: [String: Any] = [:]
                                    argsMap["id"] = currentListenerId
                                    argsMap["speedTestError"] = error.localizedDescription
                                    argsMap["type"] = 1
                                    DispatchQueue.main.async {
                                        SwiftInternetSpeedTestPlugin.channel.invokeMethod("callListener", arguments: argsMap)
                                    }
                                }
                            })
                            break
                case "startUploadTesting":
                    self.speedTest.runUploadTest(for: URL(string: testServer)!, size: fileSize, timeout: 20000, authToken: authToken, current: { (currentSpeed) in
                                                    var argsMap: [String: Any] = [:]
                                                    argsMap["id"] = currentListenerId
                                                    argsMap["transferRate"] = self.getSpeedInBytes(speed: currentSpeed)
                                                    argsMap["percent"] = 50
                                                    argsMap["type"] = 2
                                                   DispatchQueue.main.async {
                                                       SwiftInternetSpeedTestPlugin.channel.invokeMethod("callListener", arguments: argsMap)
                                                   }
                                               }, final: { (resultSpeed) in
                                                   switch resultSpeed {
                                                       
                                                   case .value(let finalSpeed):
                                                        
                                                        var argsMap: [String: Any] = [:]
                                                        argsMap["id"] = currentListenerId
                                                        argsMap["transferRate"] = self.getSpeedInBytes(speed: finalSpeed)
                                                        argsMap["percent"] = 50
                                                        argsMap["type"] = 0
                                                        
                                                       DispatchQueue.main.async {
                                                           SwiftInternetSpeedTestPlugin.channel.invokeMethod("callListener", arguments: argsMap)
                                                       }
                                                   case .error(let error):
                                                    
                                                       print("Error is \(error.localizedDescription)")
                                                       
                                                       var argsMap: [String: Any] = [:]
                                                       argsMap["id"] = currentListenerId
                                                       argsMap["speedTestError"] = error.localizedDescription
                                                       argsMap["type"] = 1
                                                       DispatchQueue.main.async {
                                                        SwiftInternetSpeedTestPlugin.channel.invokeMethod("callListener", arguments: argsMap)
                                                       }
                                                   }
                                               })
                    break
                default:
                    break
                }
            }
        }
        callbackById[currentListenerId] = fun
        fun()
    }
    
    func getSpeedInBytes(speed: Speed) -> Double {
        var rate = speed.value
        if speed.units == .Kbps {
            rate = rate * 1000
        } else if speed.units == .Mbps {
            rate = rate * 1000 * 1000
        } else  {
            rate = rate * 1000 * 1000 * 1000
        }
        return rate
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
            if (call.method == "getPlatformVersion") {
                result("iOS " + UIDevice.current.systemVersion)
            } else if (call.method == "startListening") {
                mapToCall(result: result, arguments: call.arguments)
            } else if (call.method == "cancelListening") {
//                cancelListening(arguments: call.arguments, result: result)
            } else if call.method.elementsEqual("stopDownloadTest") {
                self.speedTest.stopDownloadTest()
            }
    }
}
