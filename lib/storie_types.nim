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
    lifecycle*: string  ## Lifecycle hook: "render", "update", "init", "input", "shutdown", "enter", "exit"
    language*: string
  
  FrontMatter* = Table[string, string]
  
  MarkdownElement* = object
    ## Represents inline markdown formatting (bold, italic, links)
    text*: string
    bold*: bool
    italic*: bool
    isLink*: bool
    linkUrl*: string
  
  ContentBlockKind* = enum
    TextBlock, CodeBlock_Content, HeadingBlock
  
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
    styleSheet*: StyleSheet      ## Style configurations from front matter
    codeBlocks*: seq[CodeBlock]  ## Flat list of all code blocks (for backward compatibility)
    sections*: seq[Section]      ## Structured section-based view
