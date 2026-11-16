import Foundation
import CryptoKit

/// Resumable model downloader with integrity verification and progress reporting
class ModelDownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String?
    
    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    private var session: URLSession!
    private var destinationFileName: String = ""
    private var expectedSHA256: String?
    private var completionHandler: ((Result<URL, Error>) -> Void)?
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    func startDownload(url: URL, fileName: String, expectedSHA256: String? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
        self.destinationFileName = fileName
        self.expectedSHA256 = expectedSHA256
        self.completionHandler = completion
        self.isDownloading = true
        self.errorMessage = nil
        self.downloadProgress = 0.0
        
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
    }
    
    func pauseDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData = data
            DispatchQueue.main.async {
                self?.isDownloading = false
            }
        })
    }
    
    func resumeDownload() {
        guard let data = resumeData else { return }
        let task = session.downloadTask(withResumeData: data)
        self.downloadTask = task
        self.isDownloading = true
        task.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        resumeData = nil
        isDownloading = false
        downloadProgress = 0.0
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.downloadedBytes = totalBytesWritten
        self.totalBytes = totalBytesExpectedToWrite
        if totalBytesExpectedToWrite > 0 {
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.isDownloading = false
        
        do {
            let targetURL = AppConfiguration.modelsDirectory.appendingPathComponent(destinationFileName)
            
            // Verify checksum if provided
            if let expectedChecksum = expectedSHA256, !expectedChecksum.isEmpty {
                let fileData = try Data(contentsOf: location, options: .mappedIfSafe)
                let hash = SHA256.hash(data: fileData)
                let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                
                guard hashString.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
                    throw NSError(domain: "SmolMax.Download", code: 409, userInfo: [NSLocalizedDescriptionKey: "SHA-256 verification failed! Corrupted model file."])
                }
            }
            
            let fm = FileManager.default
            if fm.fileExists(atPath: targetURL.path) {
                try fm.removeItem(at: targetURL)
            }
            try fm.moveItem(at: location, to: targetURL)
            
            completionHandler?(.success(targetURL))
        } catch {
            self.errorMessage = error.localizedDescription
            completionHandler?(.failure(error))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.isDownloading = false
            self.errorMessage = error.localizedDescription
            completionHandler?(.failure(error))
        }
    }
}
