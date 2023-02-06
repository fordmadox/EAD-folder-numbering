<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:mdc="http://mdc"
    xmlns:ead="urn:isbn:1-931666-22-9" exclude-result-prefixes="#all" version="2.0">
    
    <!-- basic process, with 3 modes and 1 key:
        first we create a variable of all the top-container containers sorted in order. (i.e resort-first)
        then we create another variable that numbers the folders in those container groupings from the first variable. (i.e. folder-second)
        finally, we do an identity transformation on the entire finding aid, copying in the new folder numbers with the xpath key created in steps 1 and 2. (i.e. #all)
        pretty simple, right? 
     -->

    <xsl:output method="xml" indent="yes"/>
    
    <!-- if the container that's usally a container that should be foldered is missing a leading # sign
    by default, the transformation will be terminated.  you can change this behavior by setting this parameter to 0-->
    <xsl:param name="stop-numbering" select="1"/>
    
    <xsl:param name="folder-number-start" select="1" as="xs:integer"/>
    
    <xsl:key name="xpath-match" match="resorted-component" use="xpath/text()"/>

    <xsl:function name="mdc:container-to-number" as="xs:decimal">
        <xsl:param name="current-container" as="node()*"/>
        <xsl:variable name="primary-container-number" select="if (contains($current-container, '-')) then replace(substring-before($current-container, '-'), '\D', '') else replace($current-container, '\D', '')"/>
        <xsl:variable name="primary-container-modify">
            <xsl:choose>
                <xsl:when test="matches($current-container, '\D')">
                    <xsl:analyze-string select="$current-container" regex="(\D)(\s?)">
                        <xsl:matching-substring>
                            <xsl:value-of select="number(string-to-codepoints(upper-case(regex-group(1))))"/>
                        </xsl:matching-substring>
                    </xsl:analyze-string>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="00"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="id-attribue" select="$current-container/@id"/>
        <xsl:variable name="secondary-container-number">
            <!-- changed this xpath slightly so as to ignore containers that start with a # -->
            <xsl:value-of select="if (contains($current-container/following-sibling::ead:container[@parent eq $id-attribue][1], '-')) then 
                format-number(number(replace(substring-before($current-container/following-sibling::ead:container[@parent eq $id-attribue][1], '-'), '\D', '')), '000000')
                else if ($current-container/following-sibling::ead:container[not(starts-with(., '#'))][@parent eq $id-attribue][1])
                then format-number(number(replace($current-container/following-sibling::ead:container[@parent eq $id-attribue][1], '\D', '')), '000000')
                else '000000'"/>
        </xsl:variable>
        <!-- could do this recursively, instead, but ASpace can only have container1,2,3 as a group... and i've
            never seen more than that needed, anyway -->
        <xsl:variable name="tertiary-container-number">
            <xsl:value-of select="if (contains($current-container/following-sibling::ead:container[@parent eq $id-attribue][2], '-')) then 
                format-number(number(replace(substring-before($current-container/following-sibling::ead:container[@parent eq $id-attribue][1], '-'), '\D', '')), '000000')
                else if ($current-container/following-sibling::ead:container[not(starts-with(., '#'))][@parent eq $id-attribue][2])
                then format-number(number(replace($current-container/following-sibling::ead:container[@parent eq $id-attribue][2], '\D', '')), '000000')
                else '000000'"/>
        </xsl:variable>
        <xsl:value-of select="xs:decimal(concat($primary-container-number, '.', $primary-container-modify, $secondary-container-number, $tertiary-container-number))"/>
    </xsl:function>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <!-- selects all the top containers and sorts the lot.
    right now, this requires a #N value in the folder column / child container.
    -->
    <xsl:variable name="resorted-container-groups">
            <xsl:for-each select="//ead:container[@id][not(@parent)]">
                <xsl:sort select="mdc:container-to-number(.)"
                    data-type="number" order="ascending"/>
                <xsl:element name="resorted-component">
                    <xsl:apply-templates select="." mode="resort-first"/>
                </xsl:element>
            </xsl:for-each>
    </xsl:variable>
    
    <xsl:variable name="foldered-dsc">
        <foldered-components>
            <xsl:apply-templates select="$resorted-container-groups" mode="folder-second"/>
        </foldered-components>
    </xsl:variable>
    
    <xsl:template match="ead:container" mode="resort-first">
        <xsl:sequence select="., following-sibling::ead:container[1]"/>
        <xsl:element name="xpath">
            <xsl:call-template name="get-xpath"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="ead:container[lower-case(@type)='folder']" mode="resort-first" priority="2">
        <xsl:sequence select="."/>
    </xsl:template>
    
    <xsl:template match="ead:container[following-sibling::ead:container[1]/not(starts-with(normalize-space(.), '#'))]" mode="folder-second">
        <xsl:message terminate="{$stop-numbering}">The container with @id="<xsl:value-of select="@id"/>" includes a container that doesn't start with a # sign. This container won't be numbered.  
If this is a mistake, please update the Excel spreadsheet and then add the folder numbers after including the # sign.
If this is correct, then you can number the rest of the containers by changing the "stop-numbering" parameter value to 0 before re-transforming the file. Remember to unset this variable later, however.</xsl:message> 
    </xsl:template>
    
    <xsl:template match="ead:container[following-sibling::ead:container[1]/starts-with(normalize-space(.), '#')]" mode="folder-second">
        <xsl:sequence select="."/>
        <xsl:variable name="range" as="xs:integer">
            <xsl:value-of select="xs:integer(following-sibling::ead:container[1]/substring-after(normalize-space(.), '#'))"/>
        </xsl:variable>
        <xsl:variable name="previous-folder-numbers">
            <xsl:value-of
                select="sum(preceding::ead:container[following-sibling::ead:container[1]/contains(., '#')]/xs:integer(substring-after(following-sibling::ead:container[1]/normalize-space(.), '#')))"
            />
        </xsl:variable>
        <xsl:variable name="folder-number-current"
            select="if (following-sibling::ead:container[1] eq '#0') then ($folder-number-start + $previous-folder-numbers - 1) else $folder-number-start + $previous-folder-numbers"/>
        <xsl:variable name="folder-number-end" select="$folder-number-current + $range - 1"/>
        <xsl:element name="container" namespace="urn:isbn:1-931666-22-9">
            <xsl:attribute name="id"><xsl:value-of select="generate-id()"/></xsl:attribute>
            <xsl:attribute name="parent"><xsl:value-of select="@id"/></xsl:attribute>
            <xsl:attribute name="type">folder</xsl:attribute>
            <xsl:value-of
                select="if ($range gt 1) then concat(string($folder-number-current), '-', string($folder-number-end)) else $folder-number-current"
            />
        </xsl:element>
    </xsl:template>
    
    
    <!-- thanks, http://stackoverflow.com/questions/953197/how-do-you-output-the-current-element-path-in-xslt !!
        i had written a function to do this in XQuery, but this named template works just as well -->
    <xsl:template name="get-xpath">
        <xsl:param name="prevPath"/>
        <xsl:variable name="currPath" select="concat('/',concat('ead:',name()),'[',
            count(preceding-sibling::*[name() = name(current())])+1,']',$prevPath)"/>
        <xsl:for-each select="parent::*">
            <xsl:call-template name="get-xpath">
                <xsl:with-param name="prevPath" select="$currPath"/>
            </xsl:call-template>
        </xsl:for-each>
        <xsl:if test="not(parent::*)">
            <xsl:value-of select="$currPath"/>      
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="ead:container[lower-case(@type)='folder'][starts-with(normalize-space(.), '#')]" mode="#all"/>
    
    <xsl:template match="ead:container[lower-case(@type)='box']">
        <xsl:variable name="xpath">
            <xsl:call-template name="get-xpath"/>
        </xsl:variable>
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
        <xsl:for-each select="$foldered-dsc">
            <xsl:if test="key('xpath-match', $xpath)">
                <xsl:copy-of select="key('xpath-match', $xpath)/ead:container[lower-case(@type)='folder']"/>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <!-- 
    match game....  example:
    
    $foldered-dsc/foldered-components/resorted-component/xpath
    
    copy container[@type='Folder']
    
    <foldered-components>
       <resorted-component>
      <container xmlns="urn:isbn:1-931666-22-9"
                 xmlns:xlink="http://www.w3.org/1999/xlink"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 id="d1e191081"
                 label="Mixed materials"
                 type="Box">78</container>
      <container xmlns="urn:isbn:1-931666-22-9" parent="d1e191081" type="Folder">1242-1244</container>
      <xpath>/ead:ead[1]/ead:archdesc[1]/ead:dsc[1]/ead:c[3]/ead:c[5]/ead:c[1]/ead:did[1]/ead:container[1]</xpath>
   </resorted-component>
    ....
    </foldered-components>
    
    -->
</xsl:stylesheet>
