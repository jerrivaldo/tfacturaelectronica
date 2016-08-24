(******************************************************************************
 PROYECTO FACTURACION ELECTRONICA
 Copyright (C) 2010-2014 - Bambú Code SA de CV - Ing. Eduardo Padilla

 Esta clase se encarga de generar un Código de barras bidimensional QR, con
 base al estándar ISO/IEC 18004:2000, conteniendo los siguientes datos en el
 siguiente formato:

 1. RFC del emisor
 2. RFC del receptor
 3. Total (a 6 decimales fijos)
 4. Identificador único del timbre (UUID) asignado

 Generamos la imagen QR ayudandonos de la liberia Quaricol Open Source para
 generación de QR Codes.

 Este archivo pertenece al proyecto de codigo abierto de Bambu Code:
 http://bambucode.com/codigoabierto

 La licencia de este codigo fuente se encuentra en:
 http://github.com/bambucode/tfacturaelectronica/blob/master/LICENCIA
 ******************************************************************************)
unit GeneradorCBB;

interface

uses
  FacturaTipos,
  Windows, SysUtils, Classes,ExtCtrls, StdCtrls;

type

  {$REGION 'Documentation'}
  ///	<summary>
  ///	  <para>
  ///	    Esta clase se encarga de generar un Código de barras bidimensional
  ///	    QR, con base al estándar ISO/IEC 18004:2000, conteniendo los
  ///	    siguientes datos en el siguiente formato:
  ///	  </para>
  ///	  <para>
  ///	    1. RFC del emisor
  ///	  </para>
  ///	  <para>
  ///	    2. RFC del receptor
  ///	  </para>
  ///	  <para>
  ///	    3. Total (a 6 decimales fijos)
  ///	  </para>
  ///	  <para>
  ///	    4. Identificador único del timbre (UUID) asignado
  ///	  </para>
  ///	</summary>
  ///	<remarks>
  ///	  <note type="note">
  ///	    Generamos la imagen QR ayudandonos de la liberia Quaricol Open Source
  ///	    para generación de QR Codes.
  ///	  </note>
  ///	</remarks>
  {$ENDREGION}
  TGeneradorCBB = class
  private
  public
    {$REGION 'Documentation'}
    ///	<summary>
    ///	  Se encarga de generar la imagen del CBB para CFDI segun los
    ///	  requerimientos del SAT
    ///	</summary>
    {$ENDREGION}
    procedure AfterConstruction; override;
    function GenerarImagen(const aEmisor, aReceptor: TFEContribuyente; const
        aTotal: Currency; const aUUID, aRutaAGuardar: string): Boolean;
  end;

implementation

uses pngimage, Jpeg, DelphiZXIngQRCode,
  {$IF Compilerversion >= 20}
   Vcl.Graphics;
  {$ELSE}
   Graphics;
  {$IFEND}

procedure TGeneradorCBB.AfterConstruction;
begin
  inherited;
end;

function TGeneradorCBB.GenerarImagen(const aEmisor, aReceptor:
    TFEContribuyente; const aTotal: Currency; const aUUID, aRutaAGuardar:
    string): Boolean;
var
  cadenaParaCBB: String;
  jpgResultado: TJpegImage;
  bmpCBB, bmpCBBTamanoEsperado: TBitmap;
  qrCodeGenerator: TDelphiZXingQRCode;
  Row, Column: Integer;
  escala: Double;
const
  _TAMANO_DE_UUID = 36;
  _IMAGEN_MARGEN = 0;
  _TAMANO_PIXELES = 24;
  _ANCHO_ESTANDARD = 1200;
  _ALTO_ESTANDARD = 1200;
begin
  // Checamos que los parámetros esten correctos
  Assert(Length(aUUID) = _TAMANO_DE_UUID,
         'El UUID no tuvo la longitud correcta de ' + IntToStr(_TAMANO_DE_UUID));

  // 1. Definimos la cadena con la que vamos a generar el CBB segun la especificacion del SAT
  // segun el rubro II.E del Anexo 20
  cadenaParaCBB := Format('?re=%s&rr=%s&tt=%s&id=%s',
                          [aEmisor.RFC,
                           aReceptor.RFC,
                           FloatToStrF(aTotal, ffFixed, 17, 6),
                           aUUID]);

  // 2. Generamos el CBB
  bmpCBB := TBitmap.Create;
  qrCodeGenerator := TDelphiZXingQRCode.Create;
  try
    qrCodeGenerator.Data := cadenaParaCBB;
    qrCodeGenerator.Encoding := TQRCodeEncoding(qrAuto);
    qrCodeGenerator.QuietZone := 0;
    bmpCBB.SetSize(qrCodeGenerator.Rows, qrCodeGenerator.Columns);
    for Row := 0 to qrCodeGenerator.Rows - 1 do
    begin
      for Column := 0 to qrCodeGenerator.Columns - 1 do
      begin
        if (qrCodeGenerator.IsBlack[Row, Column]) then
        begin
          bmpCBB.Canvas.Pixels[Column, Row] := clBlack;
        end else
        begin
          bmpCBB.Canvas.Pixels[Column, Row] := clWhite;
        end;
      end;
    end;

    // 3. Debido a que el tamaño en el que se genera no es de la resolucion esperada
    // lo re-generamos
    bmpCBBTamanoEsperado := TBitmap.Create;
    jpgResultado := TJPEGImage.Create;
    try
      bmpCBBTamanoEsperado.SetSize(_ANCHO_ESTANDARD, _ALTO_ESTANDARD);
      // Establecemos el fondo blanco
      bmpCBBTamanoEsperado.Canvas.Brush.Color := clWhite;
      //bmpCBBTamanoEsperado.Canvas.FillRect(Rect(0, 0, bmpCBBTamanoEsperado.Width, bmpCBBTamanoEsperado.Height));

      // Le cambiamos la escala
      if (bmpCBBTamanoEsperado.Width < bmpCBBTamanoEsperado.Height) then
      begin
        escala := bmpCBBTamanoEsperado.Width / bmpCBB.Width;
      end else
      begin
        escala := bmpCBBTamanoEsperado.Height / bmpCBB.Height;
      end;

      // Copiamos el CBB del BMp original al nuevo con la escala esperada
      bmpCBBTamanoEsperado.Canvas.StretchDraw(Rect(0, 0, Trunc(escala * bmpCBB.Width), Trunc(escala * bmpCBB.Height)), bmpCBB);

      // Lo copiamos a una imagen JPEG
      jpgResultado.Assign(bmpCBBTamanoEsperado);
      jpgResultado.SaveToFile(aRutaAGuardar);

      Result := True;
    finally
      bmpCBB.Free;
      bmpCBBTamanoEsperado.Free;
    end;
  finally
    jpgResultado.Free;
    qrCodeGenerator.Free;
  end;

  Result := True;
end;

end.
