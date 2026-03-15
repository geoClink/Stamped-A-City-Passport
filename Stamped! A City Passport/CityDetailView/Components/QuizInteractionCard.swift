//
//  SwiftUIView.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import SwiftUI

struct QuizInteractionCard: View {
    let highScore: Int
    let isHighContrast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: highScore == 10 ? "medal.fill" : "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundColor(highScore == 10 ? (isHighContrast ? .primary : .yellow) : (isHighContrast ? .primary : .adventureOrange))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(isHighContrast ? .black : .semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .fontWeight(isHighContrast ? .bold : .regular)
                        .foregroundColor(isHighContrast ? .primary : .secondary)
                }
                
                Spacer()
                
                // SCORE BADGE
                Text("\(highScore)/10")
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(isHighContrast ? .primary : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHighContrast ? Color.clear : Color.secondary.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 1.5)
                    )
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(isHighContrast ? .primary : .tertiary)
            }
            .padding()
            .background(isHighContrast ? Color(UIColor.systemBackground) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighContrast ? Color.primary : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(RoundedButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). High score \(highScore) out of 10.")
        .accessibilityHint("Double tap to start the quiz.")
    }
    
    private var title: String {
        if highScore == 10 { return "City Mastered" }
        if highScore > 0 { return "Improve Your Score" }
        return "Architecture Quiz"
    }
    
    private var subtitle: String {
        if highScore == 10 { return "Perfect score! You're an expert." }
        if highScore > 0 { return "Can you get 10/10?" }
        return "Test your knowledge."
    }
}

struct RoundedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
