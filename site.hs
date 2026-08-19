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

  -- every page under pages/ becomes /<slug>.html
  match "pages/*" $ do
    route slugRoute
    compile
      $   getResourceBody
      >>= applyAsTemplate ctx
      >>= renderPandoc
      >>= loadAndApplyTemplate "templates/main.html"    ctx
      >>= loadAndApplyTemplate "templates/default.html" ctx
      >>= relativizeUrls

  create ["sitemap.xml"] $ do
    route idRoute
    compile $ do
      pages <- loadAll indexablePages
      let sitemapCtx = listField "pages" ctx (return pages) <> ctx
      makeItem ("" :: String) >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

  create ["robots.txt"] $ do
    route idRoute
    compile $ makeItem (unlines ["User-agent: *", "Allow: /", "", "Sitemap: " ++ siteUrl ++ "/sitemap.xml"])

-- the 404 page is served by GitHub Pages for unknown URLs and must not be listed
indexablePages :: Pattern
indexablePages = "pages/*" .&&. complement "pages/404.md"

--------------------------------------------------------------------------------

-- The URL comes from the `slug:` front-matter field so a file can be renamed
-- without breaking a published URL; falls back to the file name.
slugRoute :: Routes
slugRoute = metadataRoute $ \meta -> case lookupString "slug" meta of
  Just slug -> constRoute (slug ++ ".html")
  Nothing   -> gsubRoute "pages/" (const "") `composeRoutes` setExtension "html"

-- Root-relative path used for <link rel="canonical"> and the sitemap; the home
-- page is canonically "/" rather than "/index.html".
canonicalPathField :: Context a
canonicalPathField = field "canonical_path" $ \item -> do
  maybeRoute <- getRoute (itemIdentifier item)
  case maybeRoute of
    Nothing   -> noResult "canonical_path: item has no route"
    Just path -> return (stripIndexHtml (toUrl path))
 where
  stripIndexHtml url | "/index.html" `isSuffixOf` url = take (length url - length ("index.html" :: String)) url
                     | otherwise                      = url

siteUrl :: String
siteUrl = "https://lukaserlenbach.github.io"

siteCtx :: Integer -> Context String
siteCtx year =
  constField "site_name"         "lukas erlenbach"
    <> constField "site_url"          siteUrl
    <> constField "copyright_year"    (show year)
    <> constField "github_username"   "LukasErlenbach"
    <> constField "linkedin_username" "lukas-erlenbach"
    <> constField "email_username"    "lukaserlenbach"
    <> constField "email_domain"      "gmail"
    <> constField "email_tld"         "com"
    <> canonicalPathField
    <> defaultContext

currentYear :: IO Integer
currentYear = do
  (year, _, _) <- toGregorian . utctDay <$> getCurrentTime
  return year

-- configuration for display
config :: Configuration
config = defaultConfiguration { previewHost = "0.0.0.0", previewPort = 35730 }
