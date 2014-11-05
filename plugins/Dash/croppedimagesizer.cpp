/*
 * Copyright (C) 2014 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "croppedimagesizer.h"

#include "croppedimagesizerasyncworker.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QQmlEngine>
#include <QQuickItem>

CroppedImageSizer::CroppedImageSizer()
 : m_width(0),
   m_height(0),
   m_sourceSize(QSize(-1, -1)),
   m_worker(nullptr)
{
    connect(this, &CroppedImageSizer::inputParamsChanged, this, &CroppedImageSizer::calculateSourceSize);
}

CroppedImageSizer::~CroppedImageSizer()
{
    if (m_worker) {
        m_worker->abort();
    }
}

QUrl CroppedImageSizer::source() const
{
    return m_source;
}

void CroppedImageSizer::setSource(const QUrl &source)
{
    if (source != m_source) {
        m_source = source;
        Q_EMIT inputParamsChanged();
    }
}

qreal CroppedImageSizer::width() const
{
    return m_width;
}

void CroppedImageSizer::setWidth(qreal width)
{
    if (width != m_width) {
        m_width = width;
        Q_EMIT inputParamsChanged();
    }
}

qreal CroppedImageSizer::height() const
{
    return m_height;
}

void CroppedImageSizer::setHeight(qreal height)
{
    if (height != m_height) {
        m_height = height;
        Q_EMIT inputParamsChanged();
    }
}

QSize CroppedImageSizer::sourceSize() const
{
    return m_sourceSize;
}

void CroppedImageSizer::setSourceSize(const QSize &size)
{
    if (size != m_sourceSize) {
        m_sourceSize = size;
        Q_EMIT sourceSizeChanged();
    }
}

void CroppedImageSizer::calculateSourceSize()
{
    if (m_source.isValid() && m_width > 0 && m_height > 0 && qmlEngine(this) && qmlEngine(this)->networkAccessManager()) {
        if (m_worker) {
            m_worker->abort();
        }

        QNetworkRequest request(m_source);
        QNetworkReply *reply = qmlEngine(this)->networkAccessManager()->get(request);
        m_worker = new CroppedImageSizerAsyncWorker(this, reply);
    } else if (m_sourceSize != QSize(-1, -1)) {
        m_sourceSize = QSize(-1, -1);
        sourceSizeChanged();
    }
}
