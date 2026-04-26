import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';

class DocumentParserService {
  /// Entry point to parse supported binary files
  static Future<String> parseDocument(File file) async {
    final path = file.path.toLowerCase();
    
    if (path.endsWith('.pdf')) {
      return await _parsePdf(file);
    } else if (path.endsWith('.docx')) {
      return await _parseDocx(file);
    } else if (path.endsWith('.pptx')) {
      return await _parsePptx(file);
    } else if (path.endsWith('.xlsx')) {
      return await _parseXlsx(file);
    } else {
      throw Exception('Unsupported binary format: ${path.split('.').last}');
    }
  }

  static Future<String> _parsePdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text.trim().isNotEmpty ? text : '[No text found in PDF]';
    } catch (e) {
      debugPrint('PDF parsing error: $e');
      throw Exception('Failed to extract text from PDF.');
    }
  }

  static Future<String> _parseDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final documentFile = archive.findFile('word/document.xml');
      if (documentFile == null) {
        return '[Empty DOCX or invalid format]';
      }

      final content = utf8.decode(documentFile.content as List<int>);
      final document = XmlDocument.parse(content);
      
      // Extract text from <w:t> tags
      final textElements = document.findAllElements('w:t');
      final text = textElements.map((e) => e.innerText).join(' ');
      
      return text.trim().isNotEmpty ? text : '[No text found in DOCX]';
    } catch (e) {
      debugPrint('DOCX parsing error: $e');
      throw Exception('Failed to extract text from DOCX.');
    }
  }

  static Future<String> _parsePptx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final buffer = StringBuffer();
      
      // Find all slide XML files
      final slideFiles = archive.files.where((f) => 
        f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml')
      ).toList();

      // Sort slide1.xml, slide2.xml etc correctly
      slideFiles.sort((a, b) {
        final numA = int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return numA.compareTo(numB);
      });

      int slideNum = 1;
      for (final slideFile in slideFiles) {
        final content = utf8.decode(slideFile.content as List<int>);
        final document = XmlDocument.parse(content);
        
        // Extract text from <a:t> tags
        final textElements = document.findAllElements('a:t');
        final text = textElements.map((e) => e.innerText).join(' ');
        
        if (text.trim().isNotEmpty) {
          buffer.writeln('--- Slide $slideNum ---');
          buffer.writeln(text);
          buffer.writeln();
        }
        slideNum++;
      }
      
      return buffer.toString().trim().isNotEmpty 
          ? buffer.toString() 
          : '[No text found in PPTX slides]';
    } catch (e) {
      debugPrint('PPTX parsing error: $e');
      throw Exception('Failed to extract text from PPTX.');
    }
  }

  static Future<String> _parseXlsx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Excel text is primarily stored in sharedStrings.xml
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedStringsFile == null) {
        return '[Empty XLSX or no string data]';
      }

      final content = utf8.decode(sharedStringsFile.content as List<int>);
      final document = XmlDocument.parse(content);
      
      // Extract text from <t> tags
      final textElements = document.findAllElements('t');
      final text = textElements.map((e) => e.innerText).join('\n');
      
      return text.trim().isNotEmpty 
        ? 'XLSX Data extracted:\n$text' 
        : '[No text found in XLSX]';
    } catch (e) {
      debugPrint('XLSX parsing error: $e');
      throw Exception('Failed to extract text from XLSX.');
    }
  }
}
