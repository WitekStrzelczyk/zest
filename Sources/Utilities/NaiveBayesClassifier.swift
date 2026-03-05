import Foundation
import NaturalLanguage

/// A lightweight, probabilistic text classifier that learns from examples.
/// It uses Naive Bayes logic, ideal for short command classification on-device.
final class NaiveBayesClassifier {
    // MARK: - Training Data

    private var wordCounts: [String: [String: Int]] = [:] // [Label: [Word: Count]]
    private var labelCounts: [String: Int] = [:] // [Label: TotalDocs]
    private var vocabulary: Set<String> = []
    private var totalDocuments = 0
    private let lock = NSLock()

    // MARK: - Training

    /// Train the classifier with a labeled example.
    /// - Parameters:
    ///   - text: The natural language command (e.g., "schedule a meeting with John")
    ///   - label: The intent category (e.g., "calendar")
    func train(text: String, label: String) {
        let tokens = tokenize(text)

        lock.lock()
        defer { lock.unlock() }

        // Update label counts
        labelCounts[label, default: 0] += 1
        totalDocuments += 1

        // Update word counts for this label
        for token in tokens {
            vocabulary.insert(token)
            wordCounts[label, default: [:]][token, default: 0] += 1
        }
    }

    /// Batch train from a dictionary of [Label: [Examples]]
    func train(batch: [String: [String]]) {
        for (label, examples) in batch {
            for example in examples {
                train(text: example, label: label)
            }
        }
    }

    // MARK: - Prediction

    /// Predict the most likely label for a given text.
    /// - Returns: A tuple containing the best label and its log-probability score (higher is better).
    func predict(text: String) -> (label: String, score: Double)? {
        let tokens = tokenize(text)

        lock.lock()
        defer { lock.unlock() }

        if totalDocuments == 0 { return nil }

        var bestLabel: String?
        var bestScore = -Double.infinity

        for label in labelCounts.keys {
            let score = calculateLogProbability(tokens: tokens, label: label)

            if score > bestScore {
                bestScore = score
                bestLabel = label
            }
        }

        guard let label = bestLabel else { return nil }
        return (label, bestScore)
    }

    // MARK: - Math (Log Probability to avoid underflow)

    func calculateProbability(text: String, label: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard labelCounts[label] != nil else { return nil }
        return calculateLogProbability(tokens: tokenize(text), label: label)
    }

    private func calculateLogProbability(tokens: [String], label: String) -> Double {
        // P(Label)
        let labelProb = log(Double(labelCounts[label]!) / Double(totalDocuments))

        // P(Words | Label)
        var wordsProb = 0.0
        let totalWordsInLabel = wordCounts[label]?.values.reduce(0, +) ?? 0
        let vocabSize = vocabulary.count

        for token in tokens {
            // Laplace Smoothing (add-1 smoothing) to handle unknown words
            let wordCountInLabel = wordCounts[label]?[token] ?? 0
            let pWordGivenLabel = Double(wordCountInLabel + 1) / Double(totalWordsInLabel + vocabSize)
            wordsProb += log(pWordGivenLabel)
        }

        return labelProb + wordsProb
    }

    // MARK: - Tokenization & Lemmatization

    private func tokenize(_ text: String) -> [String] {
        // Safety: Limit input length
        let safeText = String(text.prefix(256))

        // CRITICAL: NLTagger is NOT thread-safe.
        // Creating a local instance avoids the "index out of bounds" crash
        // caused by concurrent threads resetting tagger.string.
        let localTagger = NLTagger(tagSchemes: [.lemma])
        localTagger.string = safeText

        var tokens: [String] = []
        let maxTokens = 15

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        localTagger.enumerateTags(
            in: safeText.startIndex..<safeText.endIndex,
            unit: .word,
            scheme: .lemma,
            options: options
        ) { tag, tokenRange in
            if tokens.count >= maxTokens { return false }

            let word = String(safeText[tokenRange]).lowercased()

            if let lemma = tag?.rawValue {
                tokens.append(lemma.lowercased())
            } else {
                tokens.append(word)
            }

            return true
        }

        return tokens
    }
}
