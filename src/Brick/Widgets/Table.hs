module Brick.Widgets.Table
  ( Table
  , ColumnAlignment(..)
  , table
  , alignRight
  , alignCenter
  , noBorder
  , noRowBorders
  , noColumnBorders

  , renderTable
  )
where

import Control.Monad (forM)
import Data.List (transpose, intersperse)
import qualified Data.Map as M
import Graphics.Vty (imageHeight, imageWidth)

import Brick.Types
import Brick.Widgets.Core
import Brick.Widgets.Center
import Brick.Widgets.Border

data ColumnAlignment =
    AlignLeft
    | AlignCenter
    | AlignRight
    deriving (Eq, Show, Read)

data Table n =
    Table { columnAlignments :: M.Map Int ColumnAlignment
          , tableRows :: [[Widget n]]
          , surroundingBorder :: Bool
          , rowBorders :: Bool
          , columnBorders :: Bool
          }

table :: [[Widget n]] -> Table n
table rows =
    Table { columnAlignments = mempty
          , tableRows = rows
          , surroundingBorder = True
          , rowBorders = True
          , columnBorders = True
          }

noBorder :: Table n -> Table n
noBorder t =
    t { surroundingBorder = False }

noRowBorders :: Table n -> Table n
noRowBorders t =
    t { rowBorders = False }

noColumnBorders :: Table n -> Table n
noColumnBorders t =
    t { columnBorders = False }

alignRight :: Int -> Table n -> Table n
alignRight col =
    setAlignment col AlignRight

alignCenter :: Int -> Table n -> Table n
alignCenter col =
    setAlignment col AlignCenter

setAlignment :: Int -> ColumnAlignment -> Table n -> Table n
setAlignment col a t =
    t { columnAlignments = M.insert col a (columnAlignments t) }

renderTable :: Table n -> Widget n
renderTable t =
    joinBorders $
    (if surroundingBorder t then border else id) $
    Widget Fixed Fixed $ do
        let rows = tableRows t
        cellResults <- forM rows $ mapM render
        let rowHeights = rowHeight <$> cellResults
            colWidths = colWidth <$> byColumn
            rowHeight = maximum . fmap (imageHeight . image)
            colWidth = maximum . fmap (imageWidth . image)
            byColumn = transpose cellResults
            toW = Widget Fixed Fixed . return
            totalHeight = sum rowHeights
            maybeAlign align width w =
                Widget Fixed Fixed $ do
                    result <- render w
                    case align of
                        AlignLeft -> return result
                        AlignCenter -> render $ hLimit width $ hCenter $ toW result
                        AlignRight -> render $
                                          padLeft (Pad (width - imageWidth (image result))) $
                                          toW result
            mkColumn (colIdx, width, colCells) = do
                let align = M.findWithDefault AlignLeft colIdx (columnAlignments t)
                paddedCells <- forM (zip rowHeights colCells) $ \(height, cell) ->
                    render $ maybeAlign align width $
                        padBottom (Pad (height - (imageHeight $ image cell)))
                        (toW cell)
                let maybeRowBorders = if rowBorders t
                                      then intersperse (hLimit width hBorder)
                                      else id
                render $ vBox $ maybeRowBorders $
                        toW <$> paddedCells
        columns <- mapM mkColumn $ zip3 [0..] colWidths byColumn
        let maybeColumnBorders =
                if columnBorders t
                then let rowBorderHeight = if rowBorders t
                                           then length rows - 1
                                           else 0
                     in intersperse (vLimit (totalHeight + rowBorderHeight) vBorder)
                else id
        render $ hBox $ maybeColumnBorders $ toW <$> columns