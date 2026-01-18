## Storie Types
##
## Core type definitions for the Storie markdown system.
## This module contains only type definitions and has no dependencies.

import tables

type
  StyleConfig* = object
    ## Style configuration for text rendering
    fg*: tuple[r, g, b: uint8]  ## Foreground color
    bg*: tuple[r, g, b: uint8]  ## Background color
    bold*: bool
    italic*: bool
    underline*: bool
    dim*: bool
  
  StyleSheet* = Table[string, StyleConfig]  ## Named style configurations
  
  CodeBlock* = object
    ## A code block extracted from markdown with lifecycle information
    code*: string
    lifecycle*: string  ## Lifecycle hook: "render", "update", "init", "input", "shutdown", "enter", "exit", "ondrop"
    language*: string
  
  EmbeddedContentKind* = enum
    ## Types of embedded content blocks in markdown
    FigletFont,    ## figlet:NAME blocks - FIGlet font data
    DataFile,      ## data:NAME blocks - arbitrary data
    AnsiArt,       ## ansi:NAME blocks - ANSI escape sequence art
    Custom         ## custom:NAME blocks - custom content
  
  EmbeddedContent* = object
    ## Embedded content block from markdown (non-executable data)
    name*: string              ## The NAME part after the colon
    kind*: EmbeddedContentKind ## Type of embedded content
    content*: string           ## The actual content data
  
  FrontMatter* = Table[string, string]
  
  MarkdownElement* = object
    ## Represents inline markdown formatting (bold, italic, links)
    text*: string
    bold*: bool
    italic*: bool
    isLink*: bool
    linkUrl*: string
  
  ContentBlockKind* = enum
    TextBlock, CodeBlock_Content, HeadingBlock, PreformattedBlock, AnsiBlock
  
  ContentBlock* = object
    ## A block of content within a section (text, code, or heading)
    case kind*: ContentBlockKind
    of TextBlock:
      text*: string
      elements*: seq[MarkdownElement]
    of CodeBlock_Content:
      codeBlock*: CodeBlock
    of HeadingBlock:
      level*: int
      title*: string
    of PreformattedBlock:
      content*: string
    of AnsiBlock:
      ansiContent*: string  ## Raw ANSI escape sequence content (parsed at render time)
      ansiBufferKey*: string  ## Cache key for parsed buffer (generated once)
  
  Section* = object
    ## A section represents a heading and all content until the next heading
    id*: string          ## Generated from title or explicit anchor
    title*: string       ## The heading text
    level*: int          ## Heading level (1-6)
    blocks*: seq[ContentBlock]  ## All content blocks in this section
    metadata*: Table[string, string]  ## Optional JSON metadata from heading
  
  MarkdownDocument* = object
    ## A complete parsed markdown document
    frontMatter*: FrontMatter
    styleSheet*: StyleSheet           ## Style configurations from front matter
    codeBlocks*: seq[CodeBlock]       ## Flat list of all code blocks (for backward compatibility)
    sections*: seq[Section]           ## Structured section-based view
    embeddedContent*: seq[EmbeddedContent]  ## Embedded data blocks (figlet fonts, data files, etc.)
