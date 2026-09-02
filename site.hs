{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad                   ( unless )
import           Data.List                      ( group
                                                , intercalate
                                                , isSuffixOf
                                                , sort
                                                )
import           Data.Maybe                     ( isJust
                                                , isNothing
                                                )
import           Data.Time                      ( getCurrentTime
                                                , toGregorian
                                                , utctDay
                                                )
import           Hakyll
import           System.Exit                    ( exitFailure )
import           System.IO                      ( hPutStrLn
                                                , stderr
                                                )

--------------------------------------------------------------------------------

main :: IO ()
main = do
  year <- currentYear
  hakyllWith config $ site (siteCtx year)

site :: Context String -> Rules ()
site ctx = do
  checkTranslations

  -- js, fonts, images, documents; the css sources are bundled below instead
  match ("static/**" .&&. complement cssSourcePattern) $ do
    route idRoute
    compile copyFileCompiler

  -- The stylesheets stay modular on disk but ship as a single render-blocking
  -- file, so a page costs one css request instead of six.
  match cssSourcePattern $ compile getResourceString

  create [cssBundle] $ do
    route idRoute
    compile $ do
      onDisk <- getMatches cssSourcePattern
      let unlisted = filter (`notElem` cssOrder) onDisk
      unless (null unlisted) $ fail $
        "css bundle: add these to cssOrder in site.hs so their cascade position is explicit: "
          ++ intercalate ", " (map show unlisted)
      parts <- mapM load cssOrder :: Compiler [Item String]
      makeItem $ intercalate "\n" (map itemBody parts)

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

-- Every bilingual page pair, as (German slug, English slug). The hreflang links
-- themselves are built from each page's front matter, so this table is the one
-- place that states which pages are translations of each other; checkTranslations
-- makes the build fail when the pages on disk stop agreeing with it.
translations :: [(String, String)]
translations = [("gestalt", "gestalt-en")]

-- Fails the build when pages/ and `translations` disagree: a renamed or deleted
-- slug, a page whose lang/alternate front matter contradicts the table, or a
-- page that advertises an alternate the table does not know about. Any of those
-- would otherwise ship hreflang links pointing at URLs that do not exist.
checkTranslations :: Rules ()
checkTranslations = do
  metas <- getAllMetadata "pages/*"
  let slugged  = [ (slug, meta) | (_, meta) <- metas, Just slug <- [lookupString "slug" meta] ]
      tabled   = concatMap (\(de, en) -> [de, en]) translations
      problems = concat
        [ [ "page " ++ show ident ++ " has no `slug:` in its front matter"
          | (ident, meta) <- metas
          , isNothing (lookupString "slug" meta)
          ]
        , [ "slug " ++ show slug ++ " is claimed by more than one page under pages/"
          | (slug : _ : _) <- group (sort (map fst slugged))
          ]
        , concatMap (pairProblems slugged) translations
        , [ show slug ++ " declares an alternate but is not listed in `translations` in site.hs"
          | (slug, meta) <- slugged
          , slug `notElem` tabled
          , isJust (lookupString "alternate" meta) || isJust (lookupString "alternate_lang" meta)
          ]
        ]
  preprocess $ unless (null problems) $ do
    hPutStrLn stderr "hreflang consistency check failed:"
    mapM_ (hPutStrLn stderr . ("  - " ++)) problems
    exitFailure

pairProblems :: [(String, Metadata)] -> (String, String) -> [String]
pairProblems slugged (de, en) = case (lookup de slugged, lookup en slugged) of
  (Nothing, _) -> [missing de]
  (_, Nothing) -> [missing en]
  (Just deMeta, Just enMeta) ->
    sideProblems de "de" en "en" deMeta ++ sideProblems en "en" de "de" enMeta
 where
  missing slug =
    "`translations` lists " ++ show slug ++ " but no page under pages/ has that slug"

-- One half of a pair: its own language, and the sibling it must point at.
sideProblems :: String -> String -> String -> String -> Metadata -> [String]
sideProblems slug lang sibling siblingLang meta = concat
  [ mismatch "lang"           lang
  , mismatch "alternate"      sibling
  , mismatch "alternate_lang" siblingLang
  ]
 where
  mismatch key want
    | lookupString key meta == Just want = []
    | otherwise = [ show slug ++ ": front matter `" ++ key ++ "` is "
                    ++ maybe "missing" show (lookupString key meta)
                    ++ ", `translations` says " ++ show want ]

-- the 404 page is served by GitHub Pages for unknown URLs and must not be listed
indexablePages :: Pattern
indexablePages = "pages/*" .&&. complement "pages/404.md"

-- Cascade order of the bundle: it is the order the individual <link> tags had,
-- and later rules still win, so reshuffling this changes how the site renders.
cssOrder :: [Identifier]
cssOrder = map
  (fromFilePath . ("static/css/" ++))
  ["fonts.css", "navigation.css", "general.css", "main.css", "footer.css", "syntax.css"]

-- The bundle itself is a created item, not a source, and must stay out of the
-- pattern so it is neither copied verbatim nor fed back into itself.
cssSourcePattern :: Pattern
cssSourcePattern = "static/css/*.css" .&&. complement (fromList [cssBundle])

cssBundle :: Identifier
cssBundle = "static/css/site.css"

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
