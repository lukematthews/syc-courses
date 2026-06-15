import numeral0Url from '../assets/pennants/numeral-0.svg'
import numeral1Url from '../assets/pennants/numeral-1.svg'
import numeral2Url from '../assets/pennants/numeral-2.svg'
import numeral3Url from '../assets/pennants/numeral-3.svg'
import numeral4Url from '../assets/pennants/numeral-4.svg'
import numeral5Url from '../assets/pennants/numeral-5.svg'
import numeral6Url from '../assets/pennants/numeral-6.svg'
import numeral7Url from '../assets/pennants/numeral-7.svg'
import numeral8Url from '../assets/pennants/numeral-8.svg'
import numeral9Url from '../assets/pennants/numeral-9.svg'

export type PennantDigit = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'

export type PennantDefinition = {
  digit: PennantDigit
  label: string
  imageSrc: string
}

export const pennants: PennantDefinition[] = [
  { digit: '0', label: 'Zero', imageSrc: numeral0Url },
  { digit: '1', label: 'One', imageSrc: numeral1Url },
  { digit: '2', label: 'Two', imageSrc: numeral2Url },
  { digit: '3', label: 'Three', imageSrc: numeral3Url },
  { digit: '4', label: 'Four', imageSrc: numeral4Url },
  { digit: '5', label: 'Five', imageSrc: numeral5Url },
  { digit: '6', label: 'Six', imageSrc: numeral6Url },
  { digit: '7', label: 'Seven', imageSrc: numeral7Url },
  { digit: '8', label: 'Eight', imageSrc: numeral8Url },
  { digit: '9', label: 'Nine', imageSrc: numeral9Url },
]

export function getPennant(digit: string) {
  return pennants.find((pennant) => pennant.digit === digit)
}
