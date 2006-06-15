//---------------------------------------------------------------------------
//FFusion
//Alternative DivX Codec for MacOS X
//version 2.2 (build 72)
//by Jerome Cornet
//Copyright 2002-2003 Jerome Cornet
//parts by Dan Christiansen
//Copyright 2003 Dan Christiansen
//from DivOSX by Jamby
//Copyright 2001-2002 Jamby
//uses libavcodec from ffmpeg 0.4.6
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//---------------------------------------------------------------------------
//Codec Dispatch
//---------------------------------------------------------------------------

        ComponentSelectorOffset (8)
        
        ComponentRangeCount (3)
        ComponentRangeShift (8)
        ComponentRangeMask	(FF)
        
        ComponentRangeBegin (0)
                StdComponentCall (GetMPWorkFunction)
                ComponentError	 (Unregister)
                StdComponentCall (Target)
                ComponentError   (Register)
                StdComponentCall (Version)
                StdComponentCall (CanDo)
                StdComponentCall (Close)
                StdComponentCall (Open)
        ComponentRangeEnd (0)
                
        ComponentRangeBegin (1)
                ComponentCall (GetCodecInfo)
                ComponentDelegate (GetCompressionTime)
                ComponentDelegate (GetMaxCompressionSize)
                ComponentDelegate (PreCompress)
                ComponentDelegate (BandCompress)
                ComponentDelegate (PreDecompress)
                ComponentDelegate (BandDecompress)
                ComponentDelegate (Busy)
                ComponentCall (GetCompressedImageSize)
                ComponentDelegate (GetSimilarity)
                ComponentDelegate (TrimImage)
                ComponentDelegate (RequestSettings)
                ComponentDelegate (GetSettings)
                ComponentDelegate (SetSettings)
                ComponentDelegate (Flush)
                ComponentDelegate (SetTimeCode)
                ComponentDelegate (IsImageDescriptionEquivalent)
                ComponentDelegate (NewMemory)
                ComponentDelegate (DisposeMemory)
                ComponentDelegate (HitTestData)
                ComponentDelegate (NewImageBufferMemory)
                ComponentDelegate (ExtractAndCombineFields)
                ComponentDelegate (GetMaxCompressionSizeWithSources)
                ComponentDelegate (SetTimeBase)
                ComponentDelegate (SourceChanged)
                ComponentDelegate (FlushLastFrame)
                ComponentDelegate (GetSettingsAsText)
                ComponentDelegate (GetParameterListHandle)
                ComponentDelegate (GetParameterList)
                ComponentDelegate (CreateStandardParameterDialog)
                ComponentDelegate (IsStandardParameterDialogEvent)
                ComponentDelegate (DismissStandardParameterDialog)
                ComponentDelegate (StandardParameterDialogDoAction)
                ComponentDelegate (NewImageGWorld)
                ComponentDelegate (DisposeImageGWorld)
                ComponentDelegate (HitTestDataWithFlags)
                ComponentDelegate (ValidateParameters)
                ComponentDelegate (GetBaseMPWorkFunction)
                ComponentDelegate (RequestGammaLevel)
                ComponentDelegate (GetSourceDataGammaLevel)
                ComponentDelegate (GetDecompressLatency)
        ComponentRangeEnd (1)
        
        ComponentRangeUnused (2)
        
        ComponentRangeBegin (3)
                ComponentCall (Preflight)
                ComponentCall (Initialize)
                ComponentCall (BeginBand)
                ComponentCall (DrawBand)
                ComponentCall (EndBand)
                ComponentCall (QueueStarting)
                ComponentCall (QueueStopping)
                ComponentDelegate (DroppingFrame)
                ComponentDelegate (ScheduleFrame)
                ComponentDelegate (CancelTrigger)
        ComponentRangeEnd (3)
