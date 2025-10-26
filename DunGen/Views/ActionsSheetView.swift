import SwiftUI

struct ActionsSheetView: View {
    let suggestedActions: [String]
    @Binding var showCustomInputSheet: Bool
    @Binding var isPresented: Bool
    let onActionSelected: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose Your Action")
                .font(.headline)
                .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(suggestedActions.enumerated()), id: \.offset) { index, action in
                            Button {
                                onActionSelected(action)
                                isPresented = false
                            } label: {
                                Text(action)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .id(index == 0 ? "topAction" : nil)
                        }

                        Button {
                            showCustomInputSheet = true
                            isPresented = false
                        } label: {
                            HStack {
                                Text(L10n.actionOr)
                                    .foregroundStyle(.secondary)
                                Text(L10n.actionCustom)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onAppear {
                    proxy.scrollTo("topAction", anchor: .top)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
