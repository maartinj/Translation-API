//
//  TranslationService.swift
//  Translation Demo
//
//  Created by Marcin Jędrzejak on 16/10/2024.
//

import Foundation
import Translation

@Observable
class TranslationService {
    var translatedText = ""
    var reviews: [Review] = []
    var availableLanguages: [AvailableLanguage] =  []
    
    init() {
        getSupportedLanguages()
        reviews = Review.samples
    }
    
    func removeTranslations() {
        reviews.indices.forEach { index in
            reviews[index].translatedComment = ""
        }
    }
    
    func getSupportedLanguages() {
        Task { @MainActor in
            let supportedLanguages = await LanguageAvailability().supportedLanguages
            availableLanguages = supportedLanguages.map { locale in
                AvailableLanguage(locale: locale)
            }
            .sorted()
        }
    }
    
    func translate(text: String, using session: TranslationSession) async throws {
        let response = try await session.translate(text)
        translatedText = response.targetText
    }
    
    func translateAllAtOnce(using session: TranslationSession) async throws {
        Task { @MainActor in
            let requests: [TranslationSession.Request] = reviews.map { review in
                    .init(sourceText: review.comment)
            }
            let responses = try await session.translations(from: requests)
            let stringsToTranslate = responses.map { response in
                response.targetText
            }
            for(index, translation) in stringsToTranslate.enumerated() {
                reviews[index].translatedComment = translation
            }
        }
    }
    
    func translateSequence(using session: TranslationSession) async throws {
        Task { @MainActor in
            let requests: [TranslationSession.Request] = reviews.map { review in
                    .init(sourceText: review.comment, clientIdentifier: review.id.uuidString)
            }
            for try await response in session.translate(batch: requests) {
                guard let id = UUID(uuidString: response.clientIdentifier ?? "") else { continue }
                if let index = reviews.firstIndex(where: { $0.id == id }) {
                    reviews[index].translatedComment = response.targetText
                }
            }
        }
    }
}
