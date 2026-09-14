//
//  ClinicPanelView.swift
//  AutoClinicConsult
//
//  Ingest + Ask UI mirroring the reference app's DashboardPanelView, wired
//  to APIClient. Adds four dataset selection parameters for the dashboard
//  (subject, topic, choice type, correct option) matching the Node backend's
//  medical-dataset filters, plus the Day / Afternoon / Eve time-of-day picker.
//

import SwiftUI

@MainActor
final class ClinicPanelViewModel: ObservableObject {
    @Published var timeOfDay: TimeOfDay = .day

    // Four dashboard selection parameters (mirrors lib/dataset.js filters)
    @Published var subjectName: String = "Any"
    @Published var topicName: String = "Any"
    @Published var choiceType: String = "Any"
    @Published var correctOption: String = "Any"

    @Published var question: String = ""
    @Published var isIngesting = false
    @Published var isAsking = false
    @Published var statusText: String = "Not yet ingested."
    @Published var answer: String = ""
    @Published var sources: [QuerySource] = []
    @Published var errorText: String?

    let subjectOptions = ["Any", "Anatomy", "Physiology", "Pharmacology", "Medicine", "Surgery", "Pediatrics", "Psychiatry"]
    let topicOptions = ["Any", "Cardiovascular", "Respiratory", "Nervous System", "Endocrine", "Renal", "Musculoskeletal"]
    let choiceTypeOptions = ["Any", "single", "multi"]
    let correctOptionOptions = ["Any", "a", "b", "c", "d"]

    private let api = APIClient()

    func ingest() async {
        isIngesting = true
        errorText = nil
        defer { isIngesting = false }
        do {
            let result = try await api.ingest(
                limit: 200,
                subjectName: subjectName == "Any" ? nil : subjectName,
                topicName: topicName == "Any" ? nil : topicName,
                choiceType: choiceType == "Any" ? nil : choiceType,
                correctOption: correctOption == "Any" ? nil : correctOption
            )
            statusText = "\(result.message) — \(result.recordsIngested) records, \(result.chunksIngested) chunks."
        } catch {
            errorText = error.localizedDescription
        }
    }

    func ask() async {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isAsking = true
        errorText = nil
        defer { isAsking = false }
        do {
            let result = try await api.query(question)
            answer = result.answer
            sources = result.sources
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct ClinicPanelView: View {
    @ObservedObject var viewModel: ClinicPanelViewModel
    var onTimeOfDayChange: (TimeOfDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AutoClinic Consult")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Picker("Time of day", selection: $viewModel.timeOfDay) {
                ForEach(TimeOfDay.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.timeOfDay) { _, newValue in
                onTimeOfDayChange(newValue)
            }

            Divider().overlay(.white.opacity(0.2))

            Text("Dataset filters").font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
            Group {
                filterRow("Subject", selection: $viewModel.subjectName, options: viewModel.subjectOptions)
                filterRow("Topic", selection: $viewModel.topicName, options: viewModel.topicOptions)
                filterRow("Choice type", selection: $viewModel.choiceType, options: viewModel.choiceTypeOptions)
                filterRow("Correct option", selection: $viewModel.correctOption, options: viewModel.correctOptionOptions)
            }

            Button {
                Task { await viewModel.ingest() }
            } label: {
                HStack {
                    if viewModel.isIngesting { ProgressView().tint(.white) }
                    Text("Ingest Medical Records")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Divider().overlay(.white.opacity(0.2))

            TextField("Ask about the ingested cases…", text: $viewModel.question)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await viewModel.ask() }
            } label: {
                HStack {
                    if viewModel.isAsking { ProgressView().tint(.white) }
                    Text("Ask Gemma")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            if let error = viewModel.errorText {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if !viewModel.answer.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.answer)
                            .font(.callout)
                            .foregroundStyle(.white)
                        ForEach(viewModel.sources) { source in
                            Text("• \(source.text)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(18)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.15)))
        .frame(width: 340)
    }

    @ViewBuilder
    private func filterRow(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.8)).frame(width: 100, alignment: .leading)
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }
}
