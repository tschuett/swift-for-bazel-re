import GRPC
import NIO

public func handleFailureEvent<Value>(_ name: String, error: Error,
                                      promise: EventLoopPromise<Value>) -> Void {
  if let ioerror = error as? IOError {
    let errno = ioerror.errnoCode
    print("\(name) IOError: \(error)")
    if errno == 2 {
      let status = GRPCStatus(code: .unavailable, message: error.localizedDescription)
      promise.fail(status)
    } else {
      print("\(name): \(errno)")
      promise.fail(error)
    }
  } else {
    let errorType = type(of: error)
    print("\(name) error: \(errorType): \(error)")
    promise.fail(error)
  }
}

