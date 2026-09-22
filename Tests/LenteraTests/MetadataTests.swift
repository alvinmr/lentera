import AppKit
import PDFKit
import Testing
@testable import Lentera

@Test(arguments: [false, true])
@MainActor
func readsEPUBMetadataWithDifferentNamespacesAndAttributeOrder(epub3: Bool) async throws {
  let fm = FileManager.default
  let directory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? fm.removeItem(at: directory) }
  for path in ["META-INF", "OPS", "Images"] {
    try fm.createDirectory(at: directory.appendingPathComponent(path), withIntermediateDirectories: true)
  }
  let container = """
  <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>
  <rootfile media-type="application/oebps-package+xml" full-path="OPS/book.opf"/>
  </rootfiles></container>
  """
  let package = """
  <package xmlns="http://www.idpf.org/2007/opf" xmlns:d="http://purl.org/dc/elements/1.1/">
    <metadata><d:title>Light &amp; Life &#x2014; <![CDATA[<Book>]]></d:title>
    <d:creator>Jane &#39;Doe&#39;</d:creator><meta content="art" name="cover"/></metadata>
    <manifest><item href="../Images/art%20work.png" id="art" media-type="image/png"
    \(epub3 ? "properties=\"nav cover-image\"" : "")/></manifest>
  </package>
  """
  try Data(container.utf8).write(to: directory.appendingPathComponent("META-INF/container.xml"))
  try Data(package.utf8).write(to: directory.appendingPathComponent("OPS/book.opf"))
  let cover = try #require(Data(base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aE1sAAAAASUVORK5CYII="))
  try cover.write(to: directory.appendingPathComponent("Images/art work.png"))
  let zip = Process()
  zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
  zip.currentDirectoryURL = directory
  zip.arguments = ["-qr", "fixture.epub", "META-INF", "OPS", "Images"]
  try zip.run()
  zip.waitUntilExit()
  try #require(zip.terminationStatus == 0)
  let metadata = await BookMetadata.read(from: directory.appendingPathComponent("fixture.epub"), fallbackTitle: "Fallback")
  #expect(metadata.title == "Light & Life — <Book>")
  #expect(metadata.author == "Jane 'Doe'")
  #expect(metadata.coverData == cover)

  // Older versions cached cover.xhtml as a JPG and never retried that path.
  let cached = directory.appendingPathComponent("cached.jpg")
  try Data("<html>cover</html>".utf8).write(to: cached)
  let book = BookRecord(id: UUID(), title: metadata.title, author: metadata.author,
    filePath: directory.appendingPathComponent("fixture.epub").path,
    format: .epub, coverPath: cached.path, completedAt: Date())
  let model = ConversionModel(books: [book])
  await model.refreshBookMetadata()
  let repaired = try #require(model.books.first?.coverURL)
  defer { if repaired != cached { try? fm.removeItem(at: repaired) } }
  #expect(NSImage(contentsOf: repaired) != nil)
  #expect(try Data(contentsOf: repaired) == cover)
}

@Test func missingEPUBFallsBackWithoutCrashing() async {
  let metadata = await BookMetadata.read(from: URL(fileURLWithPath: "/nonexistent/fixture.epub"), fallbackTitle: "Fallback")
  #expect(metadata.title == "Fallback")
  #expect(metadata.coverData == nil)
}

@Test func readsPDFCoverFromFirstPage() async throws {
  let fileManager = FileManager.default
  let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: directory) }

  let pageImage = NSImage(size: NSSize(width: 300, height: 450))
  pageImage.lockFocus()
  NSColor.systemIndigo.setFill()
  NSRect(x: 0, y: 0, width: 300, height: 450).fill()
  pageImage.unlockFocus()
  let document = PDFDocument()
  document.insert(PDFPage(image: pageImage)!, at: 0)
  let url = directory.appendingPathComponent("fixture.pdf")
  #expect(document.write(to: url))

  let metadata = await BookMetadata.read(from: url, fallbackTitle: "Fallback")
  #expect(metadata.title == "Fallback")
  #expect(metadata.coverData != nil)
}
