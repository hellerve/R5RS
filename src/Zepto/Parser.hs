module Zepto.Parser(readExpr, readExprList) where
import Control.Monad
import Control.Monad.Except
import Data.Array
import Data.Char
import Data.Complex
import Data.Ratio
import Numeric
import Text.ParserCombinators.Parsec hiding (spaces)
import qualified Data.HashMap.Strict

import Zepto.Types

symbol :: Parser Char
symbol = oneOf "!$%&|*+-/:<=>?@^_~"

spaces :: Parser ()
spaces = skipMany1 space

parseString :: Parser LispVal
parseString = do _ <- char '"'
                 x <- many (parseEscaped <|> noneOf"\"")
                 _ <- char '"'
                 return $ SimpleVal $ String x

parseEscaped :: forall u . GenParser Char u Char
parseEscaped =  do
    _ <- char '\\'
    c <- anyChar
    case c of
        'a' -> return '\a'
        'b' -> return '\b'
        'n' -> return '\n'
        't' -> return '\t'
        'r' -> return '\r'
        '"' -> return '\"'
        _ -> return c

parseAtom :: Parser LispVal
parseAtom = do first <- letter <|> symbol <|> oneOf "."
               rest <- many (letter <|> digit <|> symbol <|> oneOf ".")
               let atom = first : rest
               if atom == "."
                   then pzero
                   else return $ SimpleVal $ Atom atom

parseNumber :: Parser LispVal
parseNumber = try parseComplex
              <|> try parseRational
              <|> try parseStandardNum
              <|> parseDigital2
              <|> parseHex
              <|> parseOct
              <|> parseBin

parseStandardNum :: Parser LispVal
parseStandardNum = do num <- try parseReal <|> parseDigital1
                      e <- optionMaybe $ oneOf "eE"
                      case e of
                           Just _ -> do base <- parseDigital1
                                        return $ expt num base
                           Nothing -> return num
                where expt (SimpleVal (Number x)) (SimpleVal (Number y)) = SimpleVal $ Number $ x * convert y
                      expt _ _ = Nil ""
                      convert x = NumF $ 10 ** fromIntegral x

parseComplex :: Parser LispVal
parseComplex = do
    realParse <- try parseReal <|> parseDigital1
    let realPrt = case realParse of
                        SimpleVal (Number (NumI n)) -> fromInteger n
                        SimpleVal (Number (NumF f)) -> f
                        _ -> 0
    _ <- char '+'
    imagParse <- try parseReal <|> parseDigital1
    let imagPrt = case imagParse of
                        SimpleVal (Number (NumI n)) -> fromInteger n
                        SimpleVal (Number (NumF f)) -> f
                        _ -> 0
    _ <- char 'i'
    return $ SimpleVal $ Number $ NumC $ realPrt :+ imagPrt

parseRational :: Parser LispVal
parseRational = do
    numeratorParse <- parseDigital1
    case numeratorParse of
        SimpleVal (Number (NumI n)) -> do
            _ <- char '/'
            sign <- many (oneOf "-")
            num <- many1 digit
            if length sign > 1
                then pzero
                else do
                    let denominatorParse = read $ sign ++ num
                    if denominatorParse == 0
                        then return $ SimpleVal $ Number $ NumI 0
                        else return $ SimpleVal $ Number $ NumR $ n % denominatorParse
        _ -> pzero

parseReal :: Parser LispVal
parseReal = do neg <- optionMaybe $ string "-"
               before <- many1 digit
               _ <- string "."
               after <- many1 digit
               case neg of
                    Just _ -> (return . SimpleVal . Number . NumF . read) ("-" ++ before ++ "." ++ after)
                    Nothing -> (return . SimpleVal . Number . NumF . read) (before ++ "." ++ after)

parseDigital1 :: Parser LispVal
parseDigital1 = do neg <- optionMaybe $ string "-"
                   x <- many1 digit
                   case neg of
                      Just _ -> (return . SimpleVal . Number . NumI . read) ("-" ++ x)
                      Nothing -> (return . SimpleVal . Number . NumI . read) x

parseDigital2 :: Parser LispVal
parseDigital2 = do _ <- try $ string "#d"
                   x <- many1 digit
                   (return . SimpleVal . Number . NumI . read) x

parseHex :: Parser LispVal
parseHex = do _ <- try $ string "#x"
              x <- many1 hexDigit
              return $ SimpleVal $ Number $ NumI (hex2dig x)

parseOct :: Parser LispVal
parseOct = do _ <- try $ string "#o"
              x <- many1 octDigit
              return $ SimpleVal $ Number $ NumI (oct2dig x)

parseBin :: Parser LispVal
parseBin = do _ <- try $ string "#b"
              x <- many1 (oneOf "10")
              return $ SimpleVal $ Number $ NumI (bin2dig x)

oct2dig :: String -> Integer
oct2dig x = fst $ head $ readOct x

hex2dig :: String -> Integer
hex2dig x = fst $ head $ readHex x

bin2dig :: String -> Integer
bin2dig = bin2digx 0

bin2digx :: Integer -> String -> Integer
bin2digx digint "" = digint

bin2digx digint (x:xs) = let old = 2 * digint + (if x == '0' then 0 else 1) in
                            bin2digx old xs

parseList :: Parser LispVal
parseList = liftM List $ sepBy parseExpr spaces

parseDottedList :: Parser LispVal
parseDottedList = do h <- endBy parseExpr spaces
                     t <- char '.' >> spaces >> parseExpr
                     return $ DottedList h t

parseQuoted :: Parser LispVal
parseQuoted = do _ <- char '\''
                 x <- parseExpr
                 return $ List [SimpleVal $ Atom "quote", x]


parseQuasiquoted :: Parser LispVal
parseQuasiquoted = do _ <- char '`'
                      x <- parseExpr
                      return $ List [SimpleVal $ Atom "quasiquote", x]

parseUnquoted :: Parser LispVal
parseUnquoted = do _ <- try (char ',')
                   x <- parseExpr
                   return $ List [SimpleVal $ Atom "unquote", x]

parseSpliced :: Parser LispVal
parseSpliced = do _ <- try (string ",@")
                  x <- parseExpr
                  return $ List [SimpleVal $ Atom "unquote-splicing", x]

parseVect :: Parser LispVal
parseVect = do vals <- sepBy parseExpr spaces
               return $ Vector (listArray (0, length vals -1) vals)

parseBool :: Parser LispVal
parseBool = do _ <- string "#"
               x <- oneOf "tf"
               return $ case x of
                        't' -> SimpleVal $ Bool True
                        'f' -> SimpleVal $ Bool False
                        _   -> error "This will never happen."

parseChar :: Parser LispVal
parseChar = do
  _ <- try (string "#\\")
  c <- anyChar
  r <- many (letter <|> digit)
  let pchr = c : r
  case pchr of
    "alarm"     -> return $ SimpleVal $ Character '\a'
    "backspace" -> return $ SimpleVal $ Character '\b'
    "delete"    -> return $ SimpleVal $ Character '\DEL'
    "escape"    -> return $ SimpleVal $ Character '\ESC'
    "newline"   -> return $ SimpleVal $ Character '\n'
    "null"      -> return $ SimpleVal $ Character '\0'
    "return"    -> return $ SimpleVal $ Character '\n'
    "space"     -> return $ SimpleVal $ Character ' '
    "tab"       -> return $ SimpleVal $ Character '\t'
    _ -> case c : r of
        [ch] -> return $ SimpleVal $ Character ch
        ('x' : hexs) -> do
            rv <- parseHexScalar hexs
            return $ SimpleVal $ Character rv
        _ -> pzero

parseHexScalar :: Monad m => String -> m Char
parseHexScalar num = do
    let ns = Numeric.readHex num
    case ns of
        [] -> fail $ "Unable to parse hex value " ++ show num
        _ -> return $ chr $ fst $ head ns

parseComments :: Parser LispVal
parseComments = do _ <- char ';'
                   _ <- many (noneOf "\n")
                   return $ Nil ""

parseListComp :: Parser LispVal
parseListComp = do _    <- char '['
                   ret  <- parseExpr
                   _    <- string " | "
                   el   <- parseAtom
                   _    <- string " <- "
                   exr  <- parseListBody
                   comma <- optionMaybe $ string ", "
                   case comma of
                     Just _ -> do
                        cond <- parseExpr
                        _ <- char ']'
                        return $ ListComprehension ret el exr (Just cond)
                     Nothing -> do
                        _ <- char ']'
                        return $ ListComprehension ret el exr Nothing
    where parseListBody = parseExpr

parseHashMap :: Parser LispVal
parseHashMap = do vals <- sepBy parseExpr spaces
                  if length vals % 2 /= 0
                    then pzero
                    else
                      case construct [] vals of
                        Just m -> return $ HashMap $ Data.HashMap.Strict.fromList m
                        Nothing -> pzero
    where construct :: [(Simple, LispVal)] -> [LispVal] -> Maybe [(Simple, LispVal)]
          construct acc [] = Just acc
          construct acc (List [(SimpleVal a), b] : l) = construct (acc ++ [(a, b)]) l
          construct acc (DottedList [(SimpleVal a)] b : l) = construct (acc ++ [(a, b)]) l
          construct _ (_ : _) = Nothing

parseExpr :: Parser LispVal
parseExpr = parseComments
        <|> parseNumber
        <|> do _ <- try $ string "#("
               x <- parseVect
               _ <- char ')'
               return x
        <|> do _ <- char '{'
               x <- parseVect
               _ <- char '}'
               return x
        <|> parseSpliced
        <|> parseString
        <|> parseQuoted
        <|> try parseBool
        <|> parseQuasiquoted
        <|> parseUnquoted
        <|> parseChar
        <|> do _ <- try $ string "#{"
               x <- try parseHashMap
               _ <- char '}'
               return x
        <|> do _ <- char '('
               x <- try parseList <|> parseDottedList
               _ <- char ')'
               return x
        <|> try parseListComp
        <|> do _ <- char '['
               x <- parseList
               _ <- char ']'
               return $ List [SimpleVal $ Atom "quote", x]
        <|> try parseAtom

readOrThrow :: Parser a -> String -> ThrowsError a
readOrThrow parser input = case parse parser input input of
    Left err -> throwError $ ParseErr err
    Right val -> return val

-- | read a single expression
readExpr :: String -> ThrowsError LispVal
readExpr = readOrThrow parseExpr

-- | read a list of expressions
readExprList :: String -> ThrowsError [LispVal]
readExprList = readOrThrow (endBy parseExpr spaces)
