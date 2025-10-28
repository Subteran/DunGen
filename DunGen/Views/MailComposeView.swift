import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let messageBody: String
    let attachmentURL: URL?
    let attachmentMimeType: String
    let attachmentFileName: String
    @Binding var isPresented: Bool

    init(subject: String, messageBody: String, isPresented: Binding<Bool>, attachmentURL: URL? = nil, attachmentMimeType: String = "application/json", attachmentFileName: String = "gameState.json") {
        self.subject = subject
        self.messageBody = messageBody
        self.attachmentURL = attachmentURL
        self.attachmentMimeType = attachmentMimeType
        self.attachmentFileName = attachmentFileName
        self._isPresented = isPresented
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(["subteran@me.com"])
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: false)

        if let attachmentURL = attachmentURL,
           let data = try? Data(contentsOf: attachmentURL) {
            composer.addAttachmentData(data, mimeType: attachmentMimeType, fileName: attachmentFileName)
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
        }
    }
}
