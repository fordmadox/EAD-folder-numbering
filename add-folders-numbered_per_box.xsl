<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:ead="urn:isbn:1-931666-22-9"
    xmlns:xlink="http://www.w3.org/1999/xlink" 
    exclude-result-prefixes="xs"
    version="2.0">
    <xsl:output method="xml" indent="yes"></xsl:output>
    
    <xsl:param name="folder-number-start" select="1" as="xs:integer"/>
    
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- for folders to be numbered, they must have a #N value in the container/@type=Folder element -->
    <xsl:template match="ead:container[@type='Box'][following-sibling::ead:container[starts-with(., '#')]]">
        <xsl:copy-of select="."/>
        <xsl:variable name="currentBox" select="normalize-space()"/>
        <xsl:variable name="range" as="xs:integer">
            <xsl:value-of select="xs:integer(following-sibling::ead:container/substring-after(normalize-space(.), '#'))"/>
        </xsl:variable>
        <xsl:variable name="previous-folder-numbers">
            <xsl:value-of
                select="sum(preceding::ead:container[normalize-space() = $currentBox][following-sibling::ead:container/contains(., '#')]/xs:integer(substring-after(following-sibling::ead:container/normalize-space(.), '#')))"
            />
        </xsl:variable>
        <xsl:variable name="folder-number-current"
            select="if (following-sibling::ead:container eq '#0') then $previous-folder-numbers else $folder-number-start + $previous-folder-numbers"/>
        <xsl:variable name="folder-number-end" select="$folder-number-current + $range - 1"/>
        
        <xsl:element name="container" namespace="urn:isbn:1-931666-22-9">
            <xsl:attribute name="parent"><xsl:value-of select="@id"/></xsl:attribute>
            <xsl:attribute name="type">Folder</xsl:attribute><xsl:value-of
                select="if ($range gt 1) then concat(string($folder-number-current), '-', string($folder-number-end)) else $folder-number-current"
            />
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="ead:container[@type='Folder'][starts-with(normalize-space(.), '#')]"/>
    
</xsl:stylesheet>