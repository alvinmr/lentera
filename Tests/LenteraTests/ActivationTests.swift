import Foundation
import Testing

@testable import Lentera

private func makeActivation(in directory: URL, username: String) throws {
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try Data(
    """
    <activationInfo xmlns="http://ns.adobe.com/adept"><adept:credentials xmlns:adept="http://ns.adobe.com/adept">
    <adept:user>urn:uuid:1</adept:user>\(username)</adept:credentials></activationInfo>
    """.utf8
  ).write(to: directory.appendingPathComponent("activation.xml"))
  try Data("<device/>".utf8).write(to: directory.appendingPathComponent("device.xml"))
  try Data(repeating: 7, count: 16).write(to: directory.appendingPathComponent("devicesalt"))
}

@Test func activationSurvivesExportAndImport() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("source")
  let target = root.appendingPathComponent("target")
  let archive = root.appendingPathComponent("backup.zip")
  try makeActivation(
    in: source, username: #"<adept:username method="AdobeID">reader@example.com</adept:username>"#)

  #expect(AdobeActivation.account(in: source) == .adobeID("reader@example.com"))
  #expect(!AdobeActivation.isActivated(in: target))

  try await AdobeActivation.export(from: source, to: archive)
  try await AdobeActivation.importBackup(from: archive, into: target)

  #expect(AdobeActivation.isActivated(in: target))
  for name in AdobeActivation.requiredFiles {
    #expect(
      try Data(contentsOf: target.appendingPathComponent(name))
        == Data(contentsOf: source.appendingPathComponent(name)))
  }
}

@Test func importAcceptsAFolderAndReadsAnonymousAccounts() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let nested = root.appendingPathComponent("backup/.adept")
  let target = root.appendingPathComponent("target")
  try makeActivation(
    in: nested, username: #"<adept:username method="anonymous"></adept:username>"#)

  try await AdobeActivation.importBackup(from: root.appendingPathComponent("backup"), into: target)
  #expect(AdobeActivation.account(in: target) == .anonymous)
}

@Test func importRejectsFoldersWithoutActivation() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  await #expect(throws: AdobeActivation.ActivationError.self) {
    try await AdobeActivation.importBackup(from: root, into: root.appendingPathComponent("target"))
  }
}

@Test func importRejectsBackupsWhoseEntriesAreNotFiles() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let backup = root.appendingPathComponent("backup")
  for name in AdobeActivation.requiredFiles {
    try FileManager.default.createDirectory(
      at: backup.appendingPathComponent(name), withIntermediateDirectories: true)
  }
  let target = root.appendingPathComponent("target")
  try makeActivation(in: target, username: "")
  let before = try Data(contentsOf: target.appendingPathComponent("devicesalt"))

  await #expect(throws: AdobeActivation.ActivationError.self) {
    try await AdobeActivation.importBackup(from: backup, into: target)
  }
  #expect(try Data(contentsOf: target.appendingPathComponent("devicesalt")) == before)
}

@Test func loansTravelWithTheActivation() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("source")
  let target = root.appendingPathComponent("target")
  let archive = root.appendingPathComponent("backup.zip")
  try makeActivation(in: source, username: "")
  try FileManager.default.createDirectory(
    at: source.appendingPathComponent("loans"), withIntermediateDirectories: true)
  try Data("<loanToken/>".utf8).write(to: source.appendingPathComponent("loans/abc.xml"))

  try await AdobeActivation.export(from: source, to: archive)
  try await AdobeActivation.importBackup(from: archive, into: target)
  #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("loans/abc.xml").path))
}
