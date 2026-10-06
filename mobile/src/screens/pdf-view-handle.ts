export type PdfViewHandle = {
  goTo: (pageIndex: number) => void;
  paintQuotes: (quotes: string[]) => void;
  setZoom: (zoom: number) => void;
};
