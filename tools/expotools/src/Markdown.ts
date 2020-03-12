import marked from 'marked';

export enum TokenType {
  BLOCKQUOTE_END = 'blockquote_end',
  BLOCKQUOTE_START = 'blockquote_start',
  HEADING = 'heading',
  LIST_END = 'list_end',
  LIST_ITEM_END = 'list_item_end',
  LIST_ITEM_START = 'list_item_start',
  LIST_START = 'list_start',
  PARAGRAPH = 'paragraph',
  SPACE = 'space',
}

type SimpleToken<Type> = { type: Type };
type SimpleTokens =
  | TokenType.BLOCKQUOTE_START
  | TokenType.BLOCKQUOTE_END
  | TokenType.LIST_END
  | TokenType.LIST_ITEM_END
  | TokenType.SPACE;

export type TextToken<Type = any> = SimpleToken<Type> & { text: string };

export type HeadingToken = TextToken<TokenType.HEADING> & {
  depth: number;
};

export type ParagraphToken = TextToken<TokenType.PARAGRAPH>;

export type ListStartToken = SimpleToken<TokenType.LIST_START> & {
  ordered: boolean;
  start: string;
  loose: boolean;
};

export type ListItemStartToken = SimpleToken<TokenType.LIST_ITEM_START> & {
  task: boolean;
  checked?: boolean;
  loose: boolean;
};

export type Token =
  | SimpleToken<SimpleTokens>
  | HeadingToken
  | ParagraphToken
  | ListStartToken
  | ListItemStartToken;

export function lexify(text: string): Token[] {
  return marked.lexer(text);
}
