{-# LANGUAGE OverloadedStrings #-}
import           Data.List                      ( isSuffixOf )
import           Data.Time                      ( getCurrentTime
                                                , toGregorian
                                                , utctDay
                                                )
import           Hakyll

--------------------------------------------------------------------------------

main :: IO ()
main = do
  year <- currentYear
  hakyllWith config $ site (siteCtx year)

site :: Context String -> Rules ()
site ctx = do
  -- css, js, fonts, images, documents
  match "static/**" $ do
    route idRoute
    compile copyFileCompiler

  match "templates/*" $ compile templateCompiler

  -- every page under pages/ becomes /<slug>.html; all URLs stay root-relative
  -- (no relativizeUrls) because GitHub Pages serves 404.html under any path
  match "pages/*" $ do
    route slugRoute
    compile
      $   getResourceBody
      >>= applyAsTemplate ctx
      >>= renderPandoc
      >>= loadAndApplyTemplate "templates/main.html"    ctx
      >>= loadAndApplyTemplate "templates/default.html" ctx

  create ["sitemap.xml"] $ do
    route idRoute
    compile $ do
      pages <- loadAll indexablePages
      let sitemapCtx = listField "pages" ctx (return pages) <> ctx
      makeItem ("" :: String) >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

  create ["robots.txt"] $ do
    route idRoute
    compile $ makeItem (unlines ["User-agent: *", "Allow: /", "", "Sitemap: " ++ siteUrl ++ "/sitemap.xml"])

--------------------------------------------------------------------------------

-- the 404 page is served by GitHub Pages for unknown URLs and must not be listed
indexablePages :: Pattern
indexablePages = "pages/*" .&&. complement "pages/404.md"

-- The URL comes from the `slug:` front-matter field so a file can be renamed
-- without breaking a published URL; falls back to the file name.
slugRoute :: Routes
slugRoute = metadataRoute $ \meta -> case lookupString "slug" meta of
  Just slug -> constRoute (slugPath slug)
  Nothing   -> gsubRoute "pages/" (const "") `composeRoutes` setExtension "html"

slugPath :: String -> FilePath
slugPath slug = slug ++ ".html"

-- Root-relative path used for <link rel="canonical"> and the sitemap; the home
-- page is canonically "/" rather than "/index.html".
canonicalPathField :: Context a
canonicalPathField = field "canonical_path" canonicalPath

canonicalPath :: Item a -> Compiler String
canonicalPath item = do
  maybeRoute <- getRoute (itemIdentifier item)
  case maybeRoute of
    Nothing   -> noResult "canonical_path: item has no route"
    Just path -> return (stripIndexHtml (toUrl path))
 where
  stripIndexHtml url | "/index.html" `isSuffixOf` url = take (length url - length ("index.html" :: String)) url
                     | otherwise                      = url

-- Bilingual pages name their sibling by slug (`alternate: gestalt-en`) and its
-- language (`alternate_lang: en`); the path is derived here so it can never
-- drift from the sibling's route.
alternatePathField :: Context a
alternatePathField = field "alternate_path" alternatePath

alternatePath :: Item a -> Compiler String
alternatePath item = do
  maybeSlug <- getMetadataField (itemIdentifier item) "alternate"
  case maybeSlug of
    Nothing   -> noResult "alternate_path: page has no alternate"
    Just slug -> return ('/' : slugPath slug)

-- hreflang="x-default" points at the English version of a bilingual pair.
xDefaultPathField :: Context a
xDefaultPathField = field "x_default_path" $ \item -> do
  lang <- pageLang item
  if lang == defaultLang then canonicalPath item else alternatePath item

-- Open Graph wants a territory-qualified locale; fall back to the bare tag.
ogLocaleField :: Context a
ogLocaleField = field "og_locale" $ \item -> do
  lang <- pageLang item
  return $ case lang of
    "de" -> "de_DE"
    "en" -> "en_US"
    other -> other

pageLang :: Item a -> Compiler String
pageLang item = maybe defaultLang id <$> getMetadataField (itemIdentifier item) "lang"

defaultLang :: String
defaultLang = "en"

-- Front-matter strings that land inside HTML attributes must be escaped;
-- Hakyll templates interpolate verbatim.
escapedMetadataField :: String -> Context a
escapedMetadataField key = field key $ \item -> escapeHtml <$> getMetadataField' (itemIdentifier item) key

siteUrl :: String
siteUrl = "https://lukaserlenbach.github.io"

siteCtx :: Integer -> Context String
siteCtx year =
  constField "site_name"          "lukas erlenbach"
    <> constField "author_name"        "Lukas Erlenbach"
    <> constField "site_url"           siteUrl
    <> constField "copyright_year"     (show year)
    <> constField "github_username"    "LukasErlenbach"
    <> constField "linkedin_username"  "lukas-erlenbach"
    <> constField "email_username"     "lukaserlenbach"
    <> constField "email_domain"       "gmail"
    <> constField "email_tld"          "com"
    <> constField "google_site_verification" "wEjUQsgPLHLH2f8ey9_OG62PzRpH55Tku4Q6Pmle3ak"
    <> escapedMetadataField "title"
    <> escapedMetadataField "description"
    <> canonicalPathField
    <> alternatePathField
    <> xDefaultPathField
    <> ogLocaleField
    <> defaultContext
    <> constField "lang" defaultLang   -- after defaultContext so page metadata wins

currentYear :: IO Integer
currentYear = do
  (year, _, _) <- toGregorian . utctDay <$> getCurrentTime
  return year

-- configuration for display
config :: Configuration
config = defaultConfiguration { previewHost = "0.0.0.0", previewPort = 35730 }
