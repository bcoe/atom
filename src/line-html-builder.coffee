TokenIterator = require './token-iterator'
TokenTextEscapeRegex = /[&"'<>]/g
MaxTokenLength = 20000

module.exports =
class LineHtmlBuilder
  constructor: ->
    @tokenIterator = new TokenIterator

  buildLineHTML: (indentGuidesVisible, width, lineState) ->
    {screenRow, tokens, text, top, lineEnding, fold, isSoftWrapped, indentLevel, decorationClasses} = lineState

    classes = ''
    if decorationClasses?
      for decorationClass in decorationClasses
        classes += decorationClass + ' '
    classes += 'line'

    lineHTML = "<div class=\"#{classes}\" style=\"position: absolute; top: #{top}px; width: #{width}px;\" data-screen-row=\"#{screenRow}\">"

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(indentGuidesVisible, lineState)
    else
      lineHTML += @buildLineInnerHTML(indentGuidesVisible, lineState)

    lineHTML += '<span class="fold-marker"></span>' if fold
    lineHTML += "</div>"
    lineHTML

  buildEmptyLineInnerHTML: (indentGuidesVisible, lineState) ->
    {indentLevel, tabLength, endOfLineInvisibles} = lineState

    if indentGuidesVisible and indentLevel > 0
      invisibleIndex = 0
      lineHTML = ''
      for i in [0...indentLevel]
        lineHTML += "<span class='indent-guide'>"
        for j in [0...tabLength]
          if invisible = endOfLineInvisibles?[invisibleIndex++]
            lineHTML += "<span class='invisible-character'>#{invisible}</span>"
          else
            lineHTML += ' '
        lineHTML += "</span>"

      while invisibleIndex < endOfLineInvisibles?.length
        lineHTML += "<span class='invisible-character'>#{endOfLineInvisibles[invisibleIndex++]}</span>"

      lineHTML
    else
      @buildEndOfLineHTML(lineState) or '&nbsp;'

  buildLineInnerHTML: (indentGuidesVisible, lineState) ->
    {firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, invisibles} = lineState
    lineIsWhitespaceOnly = firstTrailingWhitespaceIndex is 0

    innerHTML = ""
    @tokenIterator.reset(lineState)

    while @tokenIterator.next()
      for scope in @tokenIterator.getScopeEnds()
        innerHTML += "</span>"

      for scope in @tokenIterator.getScopeStarts()
        innerHTML += "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

      tokenStart = @tokenIterator.getScreenStart()
      tokenEnd = @tokenIterator.getScreenEnd()
      tokenText = @tokenIterator.getText()
      isHardTab = @tokenIterator.isHardTab()

      if hasLeadingWhitespace = tokenStart < firstNonWhitespaceIndex
        tokenFirstNonWhitespaceIndex = firstNonWhitespaceIndex - tokenStart
      else
        tokenFirstNonWhitespaceIndex = null

      if hasTrailingWhitespace = tokenEnd > firstTrailingWhitespaceIndex
        tokenFirstTrailingWhitespaceIndex = Math.max(0, firstTrailingWhitespaceIndex - tokenStart)
      else
        tokenFirstTrailingWhitespaceIndex = null

      hasIndentGuide =
        indentGuidesVisible and
          (hasLeadingWhitespace or lineIsWhitespaceOnly)

      hasInvisibleCharacters =
        (invisibles?.tab and isHardTab) or
          (invisibles?.space and (hasLeadingWhitespace or hasTrailingWhitespace))

      innerHTML += @buildTokenHTML(tokenText, isHardTab, tokenFirstNonWhitespaceIndex, tokenFirstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters)

    for scope in @tokenIterator.getScopeEnds()
      innerHTML += "</span>"

    for scope in @tokenIterator.getScopes()
      innerHTML += "</span>"

    innerHTML += @buildEndOfLineHTML(lineState)
    innerHTML

  buildTokenHTML: (tokenText, isHardTab, firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters) ->
    if isHardTab
      classes = 'hard-tab'
      classes += ' leading-whitespace' if firstNonWhitespaceIndex?
      classes += ' trailing-whitespace' if firstTrailingWhitespaceIndex?
      classes += ' indent-guide' if hasIndentGuide
      classes += ' invisible-character' if hasInvisibleCharacters
      return "<span class='#{classes}'>#{@escapeTokenText(tokenText)}</span>"
    else
      startIndex = 0
      endIndex = tokenText.length

      leadingHtml = ''
      trailingHtml = ''

      if firstNonWhitespaceIndex?
        leadingWhitespace = tokenText.substring(0, firstNonWhitespaceIndex)

        classes = 'leading-whitespace'
        classes += ' indent-guide' if hasIndentGuide
        classes += ' invisible-character' if hasInvisibleCharacters

        leadingHtml = "<span class='#{classes}'>#{leadingWhitespace}</span>"
        startIndex = firstNonWhitespaceIndex

      if firstTrailingWhitespaceIndex?
        tokenIsOnlyWhitespace = firstTrailingWhitespaceIndex is 0
        trailingWhitespace = tokenText.substring(firstTrailingWhitespaceIndex)

        classes = 'trailing-whitespace'
        classes += ' indent-guide' if hasIndentGuide and not firstNonWhitespaceIndex? and tokenIsOnlyWhitespace
        classes += ' invisible-character' if hasInvisibleCharacters

        trailingHtml = "<span class='#{classes}'>#{trailingWhitespace}</span>"

        endIndex = firstTrailingWhitespaceIndex

      html = leadingHtml
      if tokenText.length > MaxTokenLength
        while startIndex < endIndex
          html += "<span>" + @escapeTokenText(tokenText, startIndex, startIndex + MaxTokenLength) + "</span>"
          startIndex += MaxTokenLength
      else
        html += @escapeTokenText(tokenText, startIndex, endIndex)

      html += trailingHtml
    html

  escapeTokenText: (tokenText, startIndex, endIndex) ->
    if startIndex? and endIndex? and startIndex > 0 or endIndex < tokenText.length
      tokenText = tokenText.slice(startIndex, endIndex)
    tokenText.replace(TokenTextEscapeRegex, @escapeTokenTextReplace)

  escapeTokenTextReplace: (match) ->
    switch match
      when '&' then '&amp;'
      when '"' then '&quot;'
      when "'" then '&#39;'
      when '<' then '&lt;'
      when '>' then '&gt;'
      else match

  buildEndOfLineHTML: (lineState) ->
    {endOfLineInvisibles} = lineState

    html = ''
    if endOfLineInvisibles?
      for invisible in endOfLineInvisibles
        html += "<span class='invisible-character'>#{invisible}</span>"
    html