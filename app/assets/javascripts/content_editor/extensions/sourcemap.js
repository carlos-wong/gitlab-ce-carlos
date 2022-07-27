import { Extension } from '@tiptap/core';
import Blockquote from './blockquote';
import Bold from './bold';
import BulletList from './bullet_list';
import Code from './code';
import CodeBlockHighlight from './code_block_highlight';
import FootnoteReference from './footnote_reference';
import FootnoteDefinition from './footnote_definition';
import Heading from './heading';
import HardBreak from './hard_break';
import HorizontalRule from './horizontal_rule';
import HTMLNodes from './html_nodes';
import Image from './image';
import Italic from './italic';
import Link from './link';
import ListItem from './list_item';
import OrderedList from './ordered_list';
import Paragraph from './paragraph';
import Strike from './strike';
import TaskList from './task_list';
import TaskItem from './task_item';
import Table from './table';
import TableCell from './table_cell';
import TableHeader from './table_header';
import TableRow from './table_row';

export default Extension.create({
  addGlobalAttributes() {
    return [
      {
        types: [
          Bold.name,
          Blockquote.name,
          BulletList.name,
          Code.name,
          CodeBlockHighlight.name,
          FootnoteReference.name,
          FootnoteDefinition.name,
          HardBreak.name,
          Heading.name,
          HorizontalRule.name,
          Image.name,
          Italic.name,
          Link.name,
          ListItem.name,
          OrderedList.name,
          Paragraph.name,
          Strike.name,
          TaskList.name,
          TaskItem.name,
          Table.name,
          TableCell.name,
          TableHeader.name,
          TableRow.name,
          ...HTMLNodes.map((htmlNode) => htmlNode.name),
        ],
        attributes: {
          /**
           * The reason to add a function that returns an empty
           * string in these attributes is indicate that these
           * attributes shouldn’t be rendered in the ProseMirror
           * view.
           */
          sourceMarkdown: {
            default: null,
            renderHTML: () => '',
          },
          sourceMapKey: {
            default: null,
            renderHTML: () => '',
          },
        },
      },
    ];
  },
});
